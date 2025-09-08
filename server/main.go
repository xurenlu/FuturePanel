package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/gofrs/uuid/v5"
	"nhooyr.io/websocket"
)

type Hub struct {
	mu      sync.RWMutex
	clients map[*websocket.Conn]struct{}
}

func NewHub() *Hub {
	return &Hub{clients: make(map[*websocket.Conn]struct{})}
}

func (h *Hub) Add(conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[conn] = struct{}{}
}

func (h *Hub) Remove(conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.clients, conn)
}

func (h *Hub) Broadcast(ctx context.Context, msg []byte) {
	h.mu.RLock()
	conns := make([]*websocket.Conn, 0, len(h.clients))
	for c := range h.clients {
		conns = append(conns, c)
	}
	h.mu.RUnlock()
	for _, c := range conns {
		_ = c.Write(ctx, websocket.MessageText, msg)
	}
}

type Server struct {
	hubs   map[string]*Hub
	mu     sync.RWMutex
	key    []byte
	nodeID string
	keyVer int
}

func NewServer() *Server {
	key := []byte(os.Getenv("CLUSTER_KEY"))
	if len(key) == 0 {
		key = []byte("dev-demo-key-please-change")
	}
	node := os.Getenv("NODE_ID")
	if node == "" {
		node = "node-local"
	}
	return &Server{hubs: make(map[string]*Hub), key: key, nodeID: node, keyVer: 1}
}

func (s *Server) hubFor(channel string) *Hub {
	s.mu.Lock()
	defer s.mu.Unlock()
	h, ok := s.hubs[channel]
	if !ok {
		h = NewHub()
		s.hubs[channel] = h
	}
	return h
}

func (s *Server) healthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"ok":true}`))
}

// anyChannel handles any unmatched path as a channel path.
// GET → WebSocket; POST → JSON broadcast.
func (s *Server) anyChannel(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	if path == "/" || path == "" || path == "/healthz" {
		http.NotFound(w, r)
		return
	}
	channel := "/" + strings.TrimPrefix(path, "/")
	switch r.Method {
	case http.MethodGet:
		c, err := websocket.Accept(w, r, &websocket.AcceptOptions{OriginPatterns: []string{"*"}})
		if err != nil {
			log.Println("ws accept:", err)
			return
		}
		hub := s.hubFor(channel)
		hub.Add(c)
		// broadcast a welcome/system message
		{
			sys := map[string]any{
				"title":   "System",
				"level":   "notice",
				"message": "欢迎接入 LogHUD · Channel " + channel,
				"system":  true,
				"effects": []string{"neon", "scanline"},
			}
			if raw, err := json.Marshal(sys); err == nil {
				if env, err := s.injectMeta(channel, raw); err == nil {
					hub.Broadcast(r.Context(), env)
				}
			}
		}
		defer func() {
			hub.Remove(c)
			_ = c.Close(websocket.StatusNormalClosure, "bye")
		}()
		for {
			if _, _, err := c.Read(r.Context()); err != nil {
				return
			}
		}
	case http.MethodPost:
		var raw json.RawMessage
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(&raw); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
		envelope, err := s.injectMeta(channel, raw)
		if err != nil {
			http.Error(w, "envelope error", http.StatusInternalServerError)
			return
		}
		hub := s.hubFor(channel)
		hub.Broadcast(r.Context(), envelope)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte(`{"ok":true}`))
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) injectMeta(channel string, raw json.RawMessage) ([]byte, error) {
	// parse to map
	var payload map[string]any
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, err
	}
	// meta
	now := time.Now().UTC()
	id := uuid.Must(uuid.NewV7()).String()
	meta := map[string]any{
		"id":           id,
		"ts":           now.Format(time.RFC3339Nano),
		"unixNs":       now.UnixNano(),
		"originNodeId": s.nodeID,
		"channel":      channel,
		"keyVersion":   s.keyVer,
	}
	// build temp without hmac
	payload["_meta"] = meta
	tmp, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	h := hmac.New(sha256.New, s.key)
	h.Write(tmp)
	mac := base64.StdEncoding.EncodeToString(h.Sum(nil))
	meta["hmac"] = mac
	payload["_meta"] = meta
	return json.Marshal(payload)
}

func main() {
	s := NewServer()
	r := chi.NewRouter()
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/healthz", s.healthz)
	// fallback handler for any path (channels with slashes)
	r.NotFound(s.anyChannel)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("server listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
