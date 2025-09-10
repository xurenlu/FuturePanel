package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rocky/futurepanel/jslwatcher/internal/client"
	"github.com/rocky/futurepanel/jslwatcher/internal/config"
	"github.com/rocky/futurepanel/jslwatcher/internal/watcher"
)

var (
	version = "dev"
	commit  = "unknown"
	date    = "unknown"
)

func main() {
	var (
		configPath  = flag.String("config", "/etc/jslwatcher/jslwatcher.conf", "配置文件路径")
		showVersion = flag.Bool("version", false, "显示版本信息")
		showHelp    = flag.Bool("help", false, "显示帮助信息")
		testConfig  = flag.Bool("test", false, "测试配置文件并退出")
		daemon      = flag.Bool("daemon", false, "以守护进程模式运行")
	)
	flag.Parse()

	if *showVersion {
		fmt.Printf("jslwatcher %s\n", version)
		fmt.Printf("  commit: %s\n", commit)
		fmt.Printf("  date: %s\n", date)
		os.Exit(0)
	}

	if *showHelp {
		showUsage()
		os.Exit(0)
	}

	// 加载配置
	cfg, err := config.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 验证配置
	if err := cfg.Validate(); err != nil {
		log.Fatalf("Invalid config: %v", err)
	}

	if *testConfig {
		fmt.Println("Configuration is valid")
		os.Exit(0)
	}

	// 设置日志级别
	setupLogging(cfg.General.LogLevel)

	log.Printf("Starting jslwatcher %s", version)
	log.Printf("Config loaded from: %s", *configPath)
	log.Printf("Monitoring %d files", len(cfg.Files))

	// 创建文件监控器
	fileWatcher, err := watcher.NewFileWatcher(cfg)
	if err != nil {
		log.Fatalf("Failed to create file watcher: %v", err)
	}

	// 创建 HTTP 客户端
	wsClient := client.NewClient(cfg, fileWatcher.GetEventChan())

	// 设置信号处理
	ctx, cancel := context.WithCancel(context.Background())
	setupSignalHandler(cancel)

	// 启动服务
	if err := fileWatcher.Start(); err != nil {
		log.Fatalf("Failed to start file watcher: %v", err)
	}

	if err := wsClient.Start(); err != nil {
		log.Fatalf("Failed to start HTTP client: %v", err)
	}

	log.Println("jslwatcher started successfully")

	// 如果是守护进程模式，打印状态信息
	if *daemon {
		printStatus(wsClient)
	}

	// 等待退出信号
	<-ctx.Done()

	log.Println("Shutting down jslwatcher...")

	// 优雅关闭
	if err := wsClient.Stop(); err != nil {
		log.Printf("Error stopping HTTP client: %v", err)
	}

	if err := fileWatcher.Stop(); err != nil {
		log.Printf("Error stopping file watcher: %v", err)
	}

	log.Println("jslwatcher stopped")
}

func showUsage() {
	fmt.Printf(`jslwatcher - 日志文件监控和转发工具

用法:
  jslwatcher [选项]

选项:
  -config string
        配置文件路径 (默认 "/etc/jslwatcher/jslwatcher.conf")
  -version
        显示版本信息
  -help
        显示此帮助信息
  -test
        测试配置文件并退出
  -daemon
        以守护进程模式运行

示例:
  # 使用默认配置启动
  jslwatcher

  # 使用自定义配置文件
  jslwatcher -config /path/to/config.yaml

  # 测试配置文件
  jslwatcher -test -config /path/to/config.yaml

  # 以守护进程模式运行
  jslwatcher -daemon

配置文件格式:
  配置文件使用 YAML 格式，详细说明请参考:
  https://github.com/rocky/futurepanel/blob/main/jslwatcher/README.md

`)
}

func setupLogging(level string) {
	// 设置日志格式
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// 这里可以根据 level 设置不同的日志级别
	// 简单实现，生产环境可以使用更完整的日志库
	switch level {
	case "debug":
		log.SetOutput(os.Stdout)
	case "info":
		log.SetOutput(os.Stdout)
	case "warn", "warning":
		log.SetOutput(os.Stderr)
	case "error":
		log.SetOutput(os.Stderr)
	default:
		log.SetOutput(os.Stdout)
	}
}

func setupSignalHandler(cancel context.CancelFunc) {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM, syscall.SIGQUIT)

	go func() {
		sig := <-c
		log.Printf("Received signal: %v", sig)
		cancel()
	}()
}

func printStatus(wsClient *client.Client) {
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			status := wsClient.GetConnectionStatus()
			connected := 0
			total := len(status)

			for _, isConnected := range status {
				if isConnected {
					connected++
				}
			}

			log.Printf("Connection status: %d/%d servers connected", connected, total)
		}
	}()
}
