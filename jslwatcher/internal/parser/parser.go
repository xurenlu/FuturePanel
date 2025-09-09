package parser

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// LogEntry 标准化的日志条目
type LogEntry struct {
	Timestamp   time.Time              `json:"timestamp"`
	Level       string                 `json:"level"`
	Message     string                 `json:"message"`
	Host        string                 `json:"host,omitempty"`
	RemoteIP    string                 `json:"remote_ip,omitempty"`
	Method      string                 `json:"method,omitempty"`
	URL         string                 `json:"url,omitempty"`
	StatusCode  int                    `json:"status_code,omitempty"`
	UserAgent   string                 `json:"user_agent,omitempty"`
	Referrer    string                 `json:"referrer,omitempty"`
	Size        int64                  `json:"size,omitempty"`
	Duration    float64                `json:"duration,omitempty"`
	Error       string                 `json:"error,omitempty"`
	Stack       string                 `json:"stack,omitempty"`
	Extra       map[string]interface{} `json:"extra,omitempty"`
	OriginalLog string                 `json:"original_log"`
	Source      string                 `json:"source"`
}

// Parser 接口定义
type Parser interface {
	Parse(line string) (*LogEntry, error)
	GetFormat() string
}

// CreateParser 根据格式创建解析器
func CreateParser(format string) (Parser, error) {
	switch format {
	case "jsonlines":
		return &JSONLinesParser{}, nil
	case "nginx-access":
		return &NginxAccessParser{}, nil
	case "nginx-error":
		return &NginxErrorParser{}, nil
	case "java-log":
		return &JavaLogParser{}, nil
	case "php-error":
		return &PHPErrorParser{}, nil
	default:
		return nil, fmt.Errorf("unsupported format: %s", format)
	}
}

// JSONLinesParser JSON Lines 格式解析器
type JSONLinesParser struct{}

func (p *JSONLinesParser) GetFormat() string {
	return "jsonlines"
}

func (p *JSONLinesParser) Parse(line string) (*LogEntry, error) {
	var entry LogEntry
	if err := json.Unmarshal([]byte(line), &entry); err != nil {
		// 如果不是标准格式，尝试解析为通用 JSON
		var raw map[string]interface{}
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			return nil, fmt.Errorf("failed to parse JSON: %w", err)
		}

		entry = LogEntry{
			Timestamp:   time.Now(),
			OriginalLog: line,
			Source:      "jsonlines",
			Extra:       raw,
		}

		// 尝试提取常见字段
		if msg, ok := raw["message"].(string); ok {
			entry.Message = msg
		}
		if level, ok := raw["level"].(string); ok {
			entry.Level = level
		}
		if ts, ok := raw["timestamp"].(string); ok {
			if parsed, err := time.Parse(time.RFC3339, ts); err == nil {
				entry.Timestamp = parsed
			}
		}
	}

	if entry.OriginalLog == "" {
		entry.OriginalLog = line
	}
	if entry.Source == "" {
		entry.Source = "jsonlines"
	}

	return &entry, nil
}

// NginxAccessParser Nginx 访问日志解析器
type NginxAccessParser struct {
	// 常见的 Nginx 访问日志格式
	// log_format combined '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"';
	regex *regexp.Regexp
}

func (p *NginxAccessParser) GetFormat() string {
	return "nginx-access"
}

func (p *NginxAccessParser) Parse(line string) (*LogEntry, error) {
	if p.regex == nil {
		// 匹配常见的 Nginx combined 格式
		pattern := `^(\S+) - (\S+) \[([^\]]+)\] "([^"]*)" (\d+) (\d+) "([^"]*)" "([^"]*)"`
		p.regex = regexp.MustCompile(pattern)
	}

	matches := p.regex.FindStringSubmatch(line)
	if len(matches) < 9 {
		// 如果不匹配，尝试简单格式
		return p.parseSimpleFormat(line)
	}

	remoteIP := matches[1]
	timeStr := matches[3]
	request := matches[4]
	statusStr := matches[5]
	sizeStr := matches[6]
	referrer := matches[7]
	userAgent := matches[8]

	// 解析时间
	timestamp, err := time.Parse("02/Jan/2006:15:04:05 -0700", timeStr)
	if err != nil {
		timestamp = time.Now()
	}

	// 解析请求
	requestParts := strings.SplitN(request, " ", 3)
	method := ""
	url := ""
	if len(requestParts) >= 2 {
		method = requestParts[0]
		url = requestParts[1]
	}

	// 解析状态码和大小
	statusCode, _ := strconv.Atoi(statusStr)
	size, _ := strconv.ParseInt(sizeStr, 10, 64)

	return &LogEntry{
		Timestamp:   timestamp,
		Level:       p.getLogLevel(statusCode),
		Message:     fmt.Sprintf("%s %s %d", method, url, statusCode),
		RemoteIP:    remoteIP,
		Method:      method,
		URL:         url,
		StatusCode:  statusCode,
		UserAgent:   userAgent,
		Referrer:    referrer,
		Size:        size,
		OriginalLog: line,
		Source:      "nginx-access",
	}, nil
}

func (p *NginxAccessParser) parseSimpleFormat(line string) (*LogEntry, error) {
	return &LogEntry{
		Timestamp:   time.Now(),
		Level:       "info",
		Message:     line,
		OriginalLog: line,
		Source:      "nginx-access",
	}, nil
}

func (p *NginxAccessParser) getLogLevel(statusCode int) string {
	if statusCode >= 500 {
		return "error"
	} else if statusCode >= 400 {
		return "warn"
	}
	return "info"
}

// NginxErrorParser Nginx 错误日志解析器
type NginxErrorParser struct {
	regex *regexp.Regexp
}

func (p *NginxErrorParser) GetFormat() string {
	return "nginx-error"
}

func (p *NginxErrorParser) Parse(line string) (*LogEntry, error) {
	if p.regex == nil {
		// 匹配 Nginx 错误日志格式
		pattern := `^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (\d+)#(\d+): (.+)`
		p.regex = regexp.MustCompile(pattern)
	}

	matches := p.regex.FindStringSubmatch(line)
	if len(matches) < 6 {
		return &LogEntry{
			Timestamp:   time.Now(),
			Level:       "error",
			Message:     line,
			OriginalLog: line,
			Source:      "nginx-error",
		}, nil
	}

	timeStr := matches[1]
	level := matches[2]
	message := matches[5]

	timestamp, err := time.Parse("2006/01/02 15:04:05", timeStr)
	if err != nil {
		timestamp = time.Now()
	}

	return &LogEntry{
		Timestamp:   timestamp,
		Level:       level,
		Message:     message,
		OriginalLog: line,
		Source:      "nginx-error",
	}, nil
}

// JavaLogParser Java 日志解析器 (支持常见的 logback/log4j 格式)
type JavaLogParser struct {
	regex *regexp.Regexp
}

func (p *JavaLogParser) GetFormat() string {
	return "java-log"
}

func (p *JavaLogParser) Parse(line string) (*LogEntry, error) {
	if p.regex == nil {
		// 匹配常见的 Java 日志格式: 2023-12-01 10:30:45.123 [INFO] com.example.Class - Message
		pattern := `^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}[.,]\d{3}) \[([^\]]+)\] ([^-]+) - (.+)`
		p.regex = regexp.MustCompile(pattern)
	}

	matches := p.regex.FindStringSubmatch(line)
	if len(matches) < 5 {
		// 尝试简单格式匹配
		return p.parseSimpleJavaLog(line)
	}

	timeStr := matches[1]
	level := strings.TrimSpace(matches[2])
	logger := strings.TrimSpace(matches[3])
	message := matches[4]

	// 处理时间格式（逗号或点作为毫秒分隔符）
	timeStr = strings.Replace(timeStr, ",", ".", 1)
	timestamp, err := time.Parse("2006-01-02 15:04:05.000", timeStr)
	if err != nil {
		timestamp = time.Now()
	}

	entry := &LogEntry{
		Timestamp:   timestamp,
		Level:       strings.ToLower(level),
		Message:     message,
		OriginalLog: line,
		Source:      "java-log",
		Extra: map[string]interface{}{
			"logger": logger,
		},
	}

	// 检测异常堆栈
	if strings.Contains(message, "Exception") || strings.Contains(message, "Error") {
		entry.Error = message
	}

	return entry, nil
}

func (p *JavaLogParser) parseSimpleJavaLog(line string) (*LogEntry, error) {
	level := "info"
	if strings.Contains(strings.ToUpper(line), "ERROR") {
		level = "error"
	} else if strings.Contains(strings.ToUpper(line), "WARN") {
		level = "warn"
	} else if strings.Contains(strings.ToUpper(line), "DEBUG") {
		level = "debug"
	}

	return &LogEntry{
		Timestamp:   time.Now(),
		Level:       level,
		Message:     line,
		OriginalLog: line,
		Source:      "java-log",
	}, nil
}

// PHPErrorParser PHP 错误日志解析器
type PHPErrorParser struct {
	regex *regexp.Regexp
}

func (p *PHPErrorParser) GetFormat() string {
	return "php-error"
}

func (p *PHPErrorParser) Parse(line string) (*LogEntry, error) {
	if p.regex == nil {
		// 匹配 PHP 错误日志格式: [01-Dec-2023 10:30:45 UTC] PHP Fatal error: Message in /path/file.php on line 123
		pattern := `^\[([^\]]+)\] PHP ([^:]+): (.+) in (.+) on line (\d+)`
		p.regex = regexp.MustCompile(pattern)
	}

	matches := p.regex.FindStringSubmatch(line)
	if len(matches) < 6 {
		return p.parseSimplePHPError(line)
	}

	timeStr := matches[1]
	errorType := matches[2]
	message := matches[3]
	file := matches[4]
	lineNum := matches[5]

	timestamp, err := time.Parse("02-Jan-2006 15:04:05 MST", timeStr)
	if err != nil {
		timestamp = time.Now()
	}

	level := "error"
	if strings.Contains(strings.ToLower(errorType), "warning") {
		level = "warn"
	} else if strings.Contains(strings.ToLower(errorType), "notice") {
		level = "info"
	}

	return &LogEntry{
		Timestamp: timestamp,
		Level:     level,
		Message:   message,
		Error:     fmt.Sprintf("%s: %s", errorType, message),
		Extra: map[string]interface{}{
			"file": file,
			"line": lineNum,
			"type": errorType,
		},
		OriginalLog: line,
		Source:      "php-error",
	}, nil
}

func (p *PHPErrorParser) parseSimplePHPError(line string) (*LogEntry, error) {
	level := "error"
	if strings.Contains(strings.ToLower(line), "warning") {
		level = "warn"
	} else if strings.Contains(strings.ToLower(line), "notice") {
		level = "info"
	}

	return &LogEntry{
		Timestamp:   time.Now(),
		Level:       level,
		Message:     line,
		Error:       line,
		OriginalLog: line,
		Source:      "php-error",
	}, nil
}
