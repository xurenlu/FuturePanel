package watcher

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/rocky/futurepanel/jslwatcher/internal/config"
	"github.com/rocky/futurepanel/jslwatcher/internal/parser"
)

// FileWatcher 文件监控器
type FileWatcher struct {
	config    *config.Config
	watcher   *fsnotify.Watcher
	parsers   map[string]parser.Parser
	files     map[string]*FileInfo
	eventChan chan *LogEvent
	ctx       context.Context
	cancel    context.CancelFunc
	wg        sync.WaitGroup
	mu        sync.RWMutex
}

// FileInfo 文件信息
type FileInfo struct {
	Path     string
	Config   config.FileConfig
	Parser   parser.Parser
	File     *os.File
	Reader   *bufio.Reader
	LastPos  int64
	LastSize int64
}

// LogEvent 日志事件
type LogEvent struct {
	Entry    *parser.LogEntry
	Channels []string
	Servers  []string
}

// NewFileWatcher 创建新的文件监控器
func NewFileWatcher(cfg *config.Config) (*FileWatcher, error) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, fmt.Errorf("failed to create file watcher: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())

	fw := &FileWatcher{
		config:    cfg,
		watcher:   watcher,
		parsers:   make(map[string]parser.Parser),
		files:     make(map[string]*FileInfo),
		eventChan: make(chan *LogEvent, cfg.General.BufferSize),
		ctx:       ctx,
		cancel:    cancel,
	}

	// 初始化解析器
	for _, fileConfig := range cfg.Files {
		parser, err := parser.CreateParser(fileConfig.Format)
		if err != nil {
			log.Printf("Failed to create parser for format %s: %v", fileConfig.Format, err)
			continue
		}
		fw.parsers[fileConfig.Path] = parser
	}

	return fw, nil
}

// Start 启动文件监控
func (fw *FileWatcher) Start() error {
	fw.wg.Add(1)
	go fw.watchEvents()

	// 添加所有文件到监控
	for _, fileConfig := range fw.config.Files {
		if err := fw.addFile(fileConfig); err != nil {
			log.Printf("Failed to add file %s to watcher: %v", fileConfig.Path, err)
			continue
		}
	}

	log.Printf("File watcher started, monitoring %d files", len(fw.files))
	return nil
}

// Stop 停止文件监控
func (fw *FileWatcher) Stop() error {
	fw.cancel()
	fw.wg.Wait()

	fw.mu.Lock()
	defer fw.mu.Unlock()

	// 关闭所有文件
	for _, fileInfo := range fw.files {
		if fileInfo.File != nil {
			fileInfo.File.Close()
		}
	}

	if fw.watcher != nil {
		return fw.watcher.Close()
	}

	close(fw.eventChan)
	return nil
}

// GetEventChan 获取事件通道
func (fw *FileWatcher) GetEventChan() <-chan *LogEvent {
	return fw.eventChan
}

// addFile 添加文件到监控
func (fw *FileWatcher) addFile(fileConfig config.FileConfig) error {
	fw.mu.Lock()
	defer fw.mu.Unlock()

	// 检查文件是否存在
	if _, err := os.Stat(fileConfig.Path); os.IsNotExist(err) {
		log.Printf("File %s does not exist, will monitor for creation", fileConfig.Path)
		// 监控目录以检测文件创建
		dir := filepath.Dir(fileConfig.Path)
		if err := fw.watcher.Add(dir); err != nil {
			return fmt.Errorf("failed to watch directory %s: %w", dir, err)
		}
	} else {
		// 文件存在，直接监控
		if err := fw.watcher.Add(fileConfig.Path); err != nil {
			return fmt.Errorf("failed to watch file %s: %w", fileConfig.Path, err)
		}

		// 打开文件并移动到末尾
		if err := fw.openFile(fileConfig); err != nil {
			return fmt.Errorf("failed to open file %s: %w", fileConfig.Path, err)
		}
	}

	return nil
}

// openFile 打开文件并初始化
func (fw *FileWatcher) openFile(fileConfig config.FileConfig) error {
	file, err := os.Open(fileConfig.Path)
	if err != nil {
		return err
	}

	// 获取文件信息
	stat, err := file.Stat()
	if err != nil {
		file.Close()
		return err
	}

	// 移动到文件末尾（只读取新增内容）
	_, err = file.Seek(0, io.SeekEnd)
	if err != nil {
		file.Close()
		return err
	}

	fileInfo := &FileInfo{
		Path:     fileConfig.Path,
		Config:   fileConfig,
		Parser:   fw.parsers[fileConfig.Path],
		File:     file,
		Reader:   bufio.NewReader(file),
		LastPos:  stat.Size(),
		LastSize: stat.Size(),
	}

	fw.files[fileConfig.Path] = fileInfo
	return nil
}

// watchEvents 监控文件系统事件
func (fw *FileWatcher) watchEvents() {
	defer fw.wg.Done()

	for {
		select {
		case <-fw.ctx.Done():
			return

		case event, ok := <-fw.watcher.Events:
			if !ok {
				return
			}

			if err := fw.handleEvent(event); err != nil {
				log.Printf("Error handling event %v: %v", event, err)
			}

		case err, ok := <-fw.watcher.Errors:
			if !ok {
				return
			}
			log.Printf("Watcher error: %v", err)
		}
	}
}

// handleEvent 处理文件系统事件
func (fw *FileWatcher) handleEvent(event fsnotify.Event) error {
	fw.mu.Lock()
	defer fw.mu.Unlock()

	// 查找匹配的文件配置
	var fileConfig *config.FileConfig
	for _, cfg := range fw.config.Files {
		if cfg.Path == event.Name {
			fileConfig = &cfg
			break
		}
	}

	if fileConfig == nil {
		// 检查是否是我们监控目录中的新文件
		for _, cfg := range fw.config.Files {
			if filepath.Dir(cfg.Path) == filepath.Dir(event.Name) &&
				filepath.Base(cfg.Path) == filepath.Base(event.Name) {
				fileConfig = &cfg
				break
			}
		}
	}

	if fileConfig == nil {
		return nil // 不是我们感兴趣的文件
	}

	switch {
	case event.Has(fsnotify.Write):
		return fw.handleWrite(*fileConfig)
	case event.Has(fsnotify.Create):
		return fw.handleCreate(*fileConfig)
	case event.Has(fsnotify.Remove) || event.Has(fsnotify.Rename):
		return fw.handleRemove(*fileConfig)
	}

	return nil
}

// handleWrite 处理文件写入事件
func (fw *FileWatcher) handleWrite(fileConfig config.FileConfig) error {
	fileInfo, exists := fw.files[fileConfig.Path]
	if !exists {
		return fw.openFile(fileConfig)
	}

	// 检查文件是否被截断（日志轮转）
	stat, err := fileInfo.File.Stat()
	if err != nil {
		return err
	}

	if stat.Size() < fileInfo.LastSize {
		// 文件被截断，重新打开
		fileInfo.File.Close()
		return fw.openFile(fileConfig)
	}

	// 读取新增的行
	return fw.readNewLines(fileInfo)
}

// handleCreate 处理文件创建事件
func (fw *FileWatcher) handleCreate(fileConfig config.FileConfig) error {
	// 添加文件到监控
	if err := fw.watcher.Add(fileConfig.Path); err != nil {
		return err
	}

	return fw.openFile(fileConfig)
}

// handleRemove 处理文件删除事件
func (fw *FileWatcher) handleRemove(fileConfig config.FileConfig) error {
	if fileInfo, exists := fw.files[fileConfig.Path]; exists {
		if fileInfo.File != nil {
			fileInfo.File.Close()
		}
		delete(fw.files, fileConfig.Path)
	}

	// 继续监控目录以检测文件重新创建
	dir := filepath.Dir(fileConfig.Path)
	return fw.watcher.Add(dir)
}

// readNewLines 读取文件中的新行
func (fw *FileWatcher) readNewLines(fileInfo *FileInfo) error {
	// 重新创建 reader
	fileInfo.File.Seek(fileInfo.LastPos, io.SeekStart)
	fileInfo.Reader = bufio.NewReader(fileInfo.File)

	for {
		line, err := fileInfo.Reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				// 更新文件位置
				pos, _ := fileInfo.File.Seek(0, io.SeekCurrent)
				fileInfo.LastPos = pos

				stat, _ := fileInfo.File.Stat()
				fileInfo.LastSize = stat.Size()
				break
			}
			return err
		}

		// 移除换行符
		line = line[:len(line)-1]
		if line == "" {
			continue
		}

		// 解析日志行
		if err := fw.processLogLine(fileInfo, line); err != nil {
			log.Printf("Failed to process log line from %s: %v", fileInfo.Path, err)
		}
	}

	return nil
}

// processLogLine 处理日志行
func (fw *FileWatcher) processLogLine(fileInfo *FileInfo, line string) error {
	if fileInfo.Parser == nil {
		return fmt.Errorf("no parser available for file %s", fileInfo.Path)
	}

	entry, err := fileInfo.Parser.Parse(line)
	if err != nil {
		log.Printf("Failed to parse log line from %s: %v", fileInfo.Path, err)
		// 创建一个基本的日志条目
		entry = &parser.LogEntry{
			Timestamp:   time.Now(),
			Level:       "unknown",
			Message:     line,
			OriginalLog: line,
			Source:      fileInfo.Parser.GetFormat(),
		}
	}

	// 创建日志事件
	event := &LogEvent{
		Entry:    entry,
		Channels: fileInfo.Config.Channels,
		Servers:  fileInfo.Config.Servers,
	}

	// 发送到事件通道
	select {
	case fw.eventChan <- event:
	case <-fw.ctx.Done():
		return fw.ctx.Err()
	default:
		log.Printf("Event channel full, dropping log event from %s", fileInfo.Path)
	}

	return nil
}
