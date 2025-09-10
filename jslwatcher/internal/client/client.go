package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/xurenlu/FuturePanel/jslwatcher/internal/config"
	"github.com/xurenlu/FuturePanel/jslwatcher/internal/watcher"
)

// Client HTTP 客户端（POST JSON 到内置域名）
type Client struct {
	config    *config.Config
	eventChan <-chan *watcher.LogEvent
	ctx       context.Context
	cancel    context.CancelFunc
	wg        sync.WaitGroup
	mu        sync.RWMutex
	httpc     *http.Client
}

var builtInBases = []string{
	"https://future.some.im",
	"https://future.wxside.com",
}

// NewClient 创建新的客户端
func NewClient(cfg *config.Config, eventChan <-chan *watcher.LogEvent) *Client {
	ctx, cancel := context.WithCancel(context.Background())

	client := &Client{
		config:    cfg,
		eventChan: eventChan,
		ctx:       ctx,
		cancel:    cancel,
		httpc:     &http.Client{Timeout: 3 * time.Second},
	}

	return client
}

// Start 启动客户端
func (c *Client) Start() error {
	// 启动事件处理协程
	c.wg.Add(1)
	go c.handleEvents()
	log.Printf("HTTP client started, built-in bases: %v", builtInBases)
	return nil
}

// Stop 停止客户端
func (c *Client) Stop() error {
	c.cancel()
	c.wg.Wait()
	log.Println("HTTP client stopped")
	return nil
}

// handleEvents 处理日志事件
func (c *Client) handleEvents() {
	defer c.wg.Done()

	for {
		select {
		case <-c.ctx.Done():
			return

		case event, ok := <-c.eventChan:
			if !ok {
				return
			}

			if err := c.processEvent(event); err != nil {
				log.Printf("Failed to process event: %v", err)
			}
		}
	}
}

// processEvent 处理单个日志事件
func (c *Client) processEvent(event *watcher.LogEvent) error {
	// 为每个指定的 URI path 发送日志，分别 POST 到内置域名
	for _, p := range event.Paths {
		if p == "" {
			continue
		}
		if p[0] != '/' {
			p = "/" + p
		}
		for _, base := range builtInBases {
			if err := c.postJSON(base, p, event); err != nil {
				log.Printf("Failed to post to %s%s: %v", base, p, err)
			}
		}
	}

	return nil
}

// postJSON 将日志条目作为 JSON POST 到 base+path
func (c *Client) postJSON(base string, path string, event *watcher.LogEvent) error {
	u := strings.TrimRight(base, "/") + path
	body, err := json.Marshal(event.Entry)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	req, err := http.NewRequest(http.MethodPost, u, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.httpc.Do(req)
	if err == nil && resp != nil {
		_ = resp.Body.Close()
	}
	return err
}

// GetConnectionStatus 获取所有连接状态（HTTP 版返回空集，仅兼容输出）
func (c *Client) GetConnectionStatus() map[string]bool { return map[string]bool{} }
