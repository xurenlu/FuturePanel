package client

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rocky/futurepanel/jslwatcher/internal/config"
	"github.com/rocky/futurepanel/jslwatcher/internal/watcher"
)

// Client WebSocket 客户端
type Client struct {
	config      *config.Config
	connections map[string]*ServerConnection
	eventChan   <-chan *watcher.LogEvent
	ctx         context.Context
	cancel      context.CancelFunc
	wg          sync.WaitGroup
	mu          sync.RWMutex
}

// ServerConnection 服务器连接
type ServerConnection struct {
	Name       string
	URL        string
	Channels   map[string]string // channel name -> path
	conn       *websocket.Conn
	connected  bool
	retryCount int
	mu         sync.RWMutex
}

// NewClient 创建新的客户端
func NewClient(cfg *config.Config, eventChan <-chan *watcher.LogEvent) *Client {
	ctx, cancel := context.WithCancel(context.Background())

	client := &Client{
		config:      cfg,
		connections: make(map[string]*ServerConnection),
		eventChan:   eventChan,
		ctx:         ctx,
		cancel:      cancel,
	}

	// 初始化服务器连接
	for _, serverConfig := range cfg.Servers {
		channels := make(map[string]string)
		for _, channel := range serverConfig.Channels {
			channels[channel.Name] = channel.Path
		}

		client.connections[serverConfig.Name] = &ServerConnection{
			Name:     serverConfig.Name,
			URL:      serverConfig.URL,
			Channels: channels,
		}
	}

	return client
}

// Start 启动客户端
func (c *Client) Start() error {
	// 启动事件处理协程
	c.wg.Add(1)
	go c.handleEvents()

	// 连接所有服务器
	for _, conn := range c.connections {
		c.wg.Add(1)
		go c.maintainConnection(conn)
	}

	log.Printf("WebSocket client started, connecting to %d servers", len(c.connections))
	return nil
}

// Stop 停止客户端
func (c *Client) Stop() error {
	c.cancel()
	c.wg.Wait()

	c.mu.Lock()
	defer c.mu.Unlock()

	// 关闭所有连接
	for _, conn := range c.connections {
		conn.mu.Lock()
		if conn.conn != nil {
			conn.conn.Close()
		}
		conn.mu.Unlock()
	}

	log.Println("WebSocket client stopped")
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
	// 为每个指定的服务器发送日志
	for _, serverName := range event.Servers {
		conn, exists := c.connections[serverName]
		if !exists {
			log.Printf("Unknown server: %s", serverName)
			continue
		}

		// 为每个指定的频道发送日志
		for _, channelName := range event.Channels {
			if err := c.sendToChannel(conn, channelName, event); err != nil {
				log.Printf("Failed to send to %s/%s: %v", serverName, channelName, err)
			}
		}
	}

	return nil
}

// sendToChannel 发送日志到指定频道
func (c *Client) sendToChannel(conn *ServerConnection, channelName string, event *watcher.LogEvent) error {
	conn.mu.RLock()
	path, exists := conn.Channels[channelName]
	isConnected := conn.connected
	wsConn := conn.conn
	conn.mu.RUnlock()

	if !exists {
		return fmt.Errorf("channel %s not found in server %s", channelName, conn.Name)
	}

	if !isConnected || wsConn == nil {
		return fmt.Errorf("not connected to server %s", conn.Name)
	}

	// 构造消息
	message := map[string]interface{}{
		"type":    "log",
		"path":    path,
		"data":    event.Entry,
		"channel": channelName,
	}

	// 发送消息
	conn.mu.Lock()
	defer conn.mu.Unlock()

	if conn.conn != nil {
		if err := conn.conn.WriteJSON(message); err != nil {
			// 连接出错，标记为断开
			conn.connected = false
			return fmt.Errorf("failed to send message: %w", err)
		}
	}

	return nil
}

// maintainConnection 维护与服务器的连接
func (c *Client) maintainConnection(conn *ServerConnection) {
	defer c.wg.Done()

	for {
		select {
		case <-c.ctx.Done():
			return
		default:
		}

		if err := c.connectToServer(conn); err != nil {
			log.Printf("Failed to connect to %s: %v", conn.Name, err)
			c.handleConnectionError(conn)
			continue
		}

		// 连接成功，重置重试计数
		conn.mu.Lock()
		conn.retryCount = 0
		conn.mu.Unlock()

		// 等待连接断开
		c.waitForDisconnection(conn)
	}
}

// connectToServer 连接到服务器
func (c *Client) connectToServer(conn *ServerConnection) error {
	u, err := url.Parse(conn.URL)
	if err != nil {
		return fmt.Errorf("invalid URL: %w", err)
	}

	log.Printf("Connecting to %s (%s)", conn.Name, conn.URL)

	wsConn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
	if err != nil {
		return fmt.Errorf("dial failed: %w", err)
	}

	conn.mu.Lock()
	conn.conn = wsConn
	conn.connected = true
	conn.mu.Unlock()

	log.Printf("Connected to %s", conn.Name)
	return nil
}

// waitForDisconnection 等待连接断开
func (c *Client) waitForDisconnection(conn *ServerConnection) {
	conn.mu.RLock()
	wsConn := conn.conn
	conn.mu.RUnlock()

	if wsConn == nil {
		return
	}

	// 设置读取超时
	wsConn.SetReadDeadline(time.Now().Add(60 * time.Second))

	// 读取消息以检测连接状态
	for {
		select {
		case <-c.ctx.Done():
			return
		default:
		}

		_, _, err := wsConn.ReadMessage()
		if err != nil {
			log.Printf("Connection to %s lost: %v", conn.Name, err)
			break
		}

		// 重新设置读取超时
		wsConn.SetReadDeadline(time.Now().Add(60 * time.Second))
	}

	// 清理连接
	conn.mu.Lock()
	if conn.conn != nil {
		conn.conn.Close()
		conn.conn = nil
	}
	conn.connected = false
	conn.mu.Unlock()
}

// handleConnectionError 处理连接错误
func (c *Client) handleConnectionError(conn *ServerConnection) {
	conn.mu.Lock()
	conn.retryCount++
	retryCount := conn.retryCount
	conn.mu.Unlock()

	maxRetries := c.config.General.RetryCount
	if maxRetries <= 0 {
		maxRetries = 3
	}

	if retryCount >= maxRetries {
		log.Printf("Max retries reached for %s, resetting retry count", conn.Name)
		conn.mu.Lock()
		conn.retryCount = 0
		conn.mu.Unlock()
	}

	// 计算重试延迟
	retryDelay := 5 * time.Second
	if c.config.General.RetryDelay != "" {
		if duration, err := time.ParseDuration(c.config.General.RetryDelay); err == nil {
			retryDelay = duration
		}
	}

	// 指数退避
	delay := retryDelay * time.Duration(1<<uint(retryCount-1))
	if delay > 5*time.Minute {
		delay = 5 * time.Minute
	}

	log.Printf("Retrying connection to %s in %v (attempt %d)", conn.Name, delay, retryCount)

	select {
	case <-c.ctx.Done():
		return
	case <-time.After(delay):
	}
}

// GetConnectionStatus 获取所有连接状态
func (c *Client) GetConnectionStatus() map[string]bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	status := make(map[string]bool)
	for name, conn := range c.connections {
		conn.mu.RLock()
		status[name] = conn.connected
		conn.mu.RUnlock()
	}

	return status
}
