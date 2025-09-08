package main

import (
	"bytes"
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
	clients map[*websocket.Conn]*client
	in      chan []byte
}

func NewHub() *Hub {
	return &Hub{clients: make(map[*websocket.Conn]*client), in: make(chan []byte, 1024)}
}

type client struct {
	conn *websocket.Conn
	send chan []byte
}

func (h *Hub) Add(conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	c := &client{conn: conn, send: make(chan []byte, 256)}
	h.clients[conn] = c
	go h.writePump(c)
}

func (h *Hub) Remove(conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if c, ok := h.clients[conn]; ok {
		delete(h.clients, conn)
		close(c.send)
	}
}

func (h *Hub) Broadcast(_ context.Context, msg []byte) {
	// enqueue into hub queue; drop if full to preserve latency
	select {
	case h.in <- msg:
	default:
	}
}

func (h *Hub) writePump(c *client) {
	for msg := range c.send {
		// decouple from request context, with short timeout to avoid head-of-line blocking
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		_ = c.conn.Write(ctx, websocket.MessageText, msg)
		cancel()
	}
}

func (h *Hub) run() {
	for msg := range h.in {
		h.mu.RLock()
		for _, c := range h.clients {
			select {
			case c.send <- msg:
			default:
				// drop per slow client to keep overall latency low
			}
		}
		h.mu.RUnlock()
	}
}

type Server struct {
	hubs   map[string]*Hub
	mu     sync.RWMutex
	key    []byte
	nodeID string
	keyVer int
	peers  []string
	httpc  *http.Client
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
	var peers []string
	if v := os.Getenv("PEERS"); v != "" {
		parts := strings.Split(v, ",")
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p != "" {
				peers = append(peers, p)
			}
		}
	}
	return &Server{
		hubs:   make(map[string]*Hub),
		key:    key,
		nodeID: node,
		keyVer: 1,
		peers:  peers,
		httpc:  &http.Client{Timeout: 2 * time.Second},
	}
}

func (s *Server) hubFor(channel string) *Hub {
	s.mu.Lock()
	defer s.mu.Unlock()
	h, ok := s.hubs[channel]
	if !ok {
		h = NewHub()
		go h.run()
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
		var tmp map[string]json.RawMessage
		_ = json.Unmarshal(raw, &tmp)
		envelope := raw
		if _, ok := tmp["_meta"]; !ok {
			var err error
			envelope, err = s.injectMeta(channel, raw)
			if err != nil {
				http.Error(w, "envelope error", http.StatusInternalServerError)
				return
			}
		}
		hub := s.hubFor(channel)
		hub.Broadcast(r.Context(), envelope)
		if r.Header.Get("X-LogHUD-Origin") == "" {
			go s.forwardToPeers(channel, envelope)
		}
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

func (s *Server) forwardToPeers(channel string, envelope []byte) {
	if len(s.peers) == 0 {
		return
	}
	for _, base := range s.peers {
		url := strings.TrimRight(base, "/") + channel
		req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(envelope))
		if err != nil {
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-LogHUD-Origin", s.nodeID)
		resp, err := s.httpc.Do(req)
		if err == nil && resp != nil {
			_ = resp.Body.Close()
		}
	}
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
