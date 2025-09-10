package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config 代表 jslwatcher 的配置
type Config struct {
	Files   []FileConfig  `yaml:"files"`
	General GeneralConfig `yaml:"general"`
}

// FileConfig 文件监控配置
type FileConfig struct {
	Path   string   `yaml:"path"`
	Format string   `yaml:"format"` // jsonlines, nginx-access, nginx-error, java-log, php-error
	Paths  []string `yaml:"paths"`  // 发送到哪些 URI 路径（如 /events/app1）
}

// GeneralConfig 通用配置
type GeneralConfig struct {
	LogLevel    string `yaml:"log_level"`
	BufferSize  int    `yaml:"buffer_size"`
	RetryCount  int    `yaml:"retry_count"`
	RetryDelay  string `yaml:"retry_delay"`
	MaxFileSize string `yaml:"max_file_size"`
}

// DefaultConfig 返回默认配置
func DefaultConfig() *Config {
	return &Config{
		Files: []FileConfig{
			{
				Path:   "/var/log/nginx/access.log",
				Format: "nginx-access",
				Paths:  []string{"/logs/default"},
			},
			{
				Path:   "/var/log/nginx/error.log",
				Format: "nginx-error",
				Paths:  []string{"/logs/errors"},
			},
		},
		General: GeneralConfig{
			LogLevel:    "info",
			BufferSize:  1000,
			RetryCount:  3,
			RetryDelay:  "5s",
			MaxFileSize: "100MB",
		},
	}
}

// LoadConfig 从文件加载配置
func LoadConfig(configPath string) (*Config, error) {
	if configPath == "" {
		configPath = "/etc/jslwatcher/jslwatcher.conf"
	}

	// 如果配置文件不存在，创建默认配置
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		if err := createDefaultConfig(configPath); err != nil {
			return nil, fmt.Errorf("failed to create default config: %w", err)
		}
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	return &config, nil
}

// SaveConfig 保存配置到文件
func SaveConfig(config *Config, configPath string) error {
	if configPath == "" {
		configPath = "/etc/jslwatcher/jslwatcher.conf"
	}

	// 确保目录存在
	if err := os.MkdirAll(filepath.Dir(configPath), 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	data, err := yaml.Marshal(config)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	if err := os.WriteFile(configPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// createDefaultConfig 创建默认配置文件
func createDefaultConfig(configPath string) error {
	defaultConfig := DefaultConfig()
	return SaveConfig(defaultConfig, configPath)
}

// Validate 验证配置
func (c *Config) Validate() error {
	if len(c.Files) == 0 {
		return fmt.Errorf("at least one file must be configured")
	}
	// 验证文件配置
	for _, file := range c.Files {
		if file.Path == "" {
			return fmt.Errorf("file path cannot be empty")
		}
		if file.Format == "" {
			return fmt.Errorf("file format cannot be empty for file %s", file.Path)
		}
		if len(file.Paths) == 0 {
			return fmt.Errorf("at least one uri path must be specified for file %s", file.Path)
		}
	}

	return nil
}
