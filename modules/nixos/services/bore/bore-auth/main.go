package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/securecookie"
)

type Config struct {
	ListenAddr     string
	FrpsAPIURL     string
	IndikoURL      string
	ClientID       string
	ClientSecret   string
	RedirectURI    string
	CookieDomain   string
	CookieSecure   bool
	SessionMaxAge  int
	HashKey        []byte
	BlockKey       []byte
}

type Session struct {
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	ExpiresAt time.Time `json:"expires_at"`
}

type PKCEState struct {
	CodeVerifier string
	RedirectTo   string
	CreatedAt    time.Time
}

type ProxyInfo struct {
	Name   string          `json:"name"`
	Status string          `json:"status"`
	Conf   json.RawMessage `json:"conf"`
}

type ProxyConf struct {
	Subdomain string            `json:"subdomain"`
	Metadatas map[string]string `json:"metadatas"`
}

type ProxyListResponse struct {
	Proxies []ProxyInfo `json:"proxies"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
	Me           string `json:"me"`
	Scope        string `json:"scope"`
	Profile      struct {
		Name  string `json:"name"`
		Email string `json:"email"`
		Photo string `json:"photo"`
		URL   string `json:"url"`
	} `json:"profile"`
}

var (
	config       Config
	secureCookie *securecookie.SecureCookie
	pkceStates   = make(map[string]PKCEState)
	pkceStatesMu sync.Mutex
	proxyCache   = make(map[string]*ProxyConf)
	proxyCacheMu sync.RWMutex
	proxyCacheAt time.Time
)

func main() {
	config = Config{
		ListenAddr:    getEnv("LISTEN_ADDR", ":8401"),
		FrpsAPIURL:    getEnv("FRPS_API_URL", "http://localhost:7400"),
		IndikoURL:     getEnv("INDIKO_URL", "https://indiko.dunkirk.sh"),
		ClientID:      getEnv("CLIENT_ID", "https://bore.dunkirk.sh"),
		ClientSecret:  getEnv("CLIENT_SECRET", ""),
		RedirectURI:   getEnv("REDIRECT_URI", "https://bore.dunkirk.sh/.auth/callback"),
		CookieDomain:  getEnv("COOKIE_DOMAIN", ".bore.dunkirk.sh"),
		CookieSecure:  getEnv("COOKIE_SECURE", "true") == "true",
		SessionMaxAge: 86400 * 7, // 7 days
	}

	hashKeyStr := getEnv("COOKIE_HASH_KEY", "")
	blockKeyStr := getEnv("COOKIE_BLOCK_KEY", "")

	if hashKeyStr == "" || blockKeyStr == "" {
		log.Println("WARNING: COOKIE_HASH_KEY and COOKIE_BLOCK_KEY not set, generating random keys")
		config.HashKey = securecookie.GenerateRandomKey(32)
		config.BlockKey = securecookie.GenerateRandomKey(32)
	} else {
		config.HashKey = decodeKey(hashKeyStr)
		config.BlockKey = decodeKey(blockKeyStr)
		log.Printf("Loaded cookie keys: hash=%d bytes, block=%d bytes", len(config.HashKey), len(config.BlockKey))
	}

	secureCookie = securecookie.New(config.HashKey, config.BlockKey)
	secureCookie.MaxAge(config.SessionMaxAge)

	// Start background cache refresh
	go refreshProxyCachePeriodically()

	http.HandleFunc("/.auth/check", handleAuthCheck)
	http.HandleFunc("/.auth/login", handleLogin)
	http.HandleFunc("/.auth/callback", handleCallback)
	http.HandleFunc("/.auth/logout", handleLogout)
	http.HandleFunc("/healthz", handleHealthz)

	log.Printf("bore-auth listening on %s", config.ListenAddr)
	log.Fatal(http.ListenAndServe(config.ListenAddr, nil))
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func handleAuthCheck(w http.ResponseWriter, r *http.Request) {
	host := r.Header.Get("X-Forwarded-Host")
	if host == "" {
		host = r.Host
	}

	subdomain := extractSubdomain(host)
	if subdomain == "" {
		w.WriteHeader(http.StatusOK)
		return
	}

	proxyConf := getProxyConf(subdomain)
	if proxyConf == nil {
		w.WriteHeader(http.StatusOK)
		return
	}

	authType := proxyConf.Metadatas["auth"]
	if authType != "indiko" {
		w.WriteHeader(http.StatusOK)
		return
	}

	session, err := getSession(r)
	if err != nil || session == nil || time.Now().After(session.ExpiresAt) {
		originalURL := r.Header.Get("X-Forwarded-Uri")
		if originalURL == "" {
			originalURL = r.URL.RequestURI()
		}
		scheme := r.Header.Get("X-Forwarded-Proto")
		if scheme == "" {
			scheme = "https"
		}

		redirectTo := fmt.Sprintf("%s://%s%s", scheme, host, originalURL)
		loginURL := fmt.Sprintf("https://%s/.auth/login?redirect=%s", config.CookieDomain[1:], url.QueryEscape(redirectTo))

		w.Header().Set("Location", loginURL)
		w.WriteHeader(http.StatusTemporaryRedirect)
		return
	}

	w.Header().Set("X-Auth-User", session.UserID)
	w.Header().Set("X-Auth-Name", session.Name)
	w.Header().Set("X-Auth-Email", session.Email)
	w.WriteHeader(http.StatusOK)
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	redirectTo := r.URL.Query().Get("redirect")
	if redirectTo == "" {
		redirectTo = "https://" + config.CookieDomain[1:]
	}

	codeVerifier := generateCodeVerifier()
	codeChallenge := generateCodeChallenge(codeVerifier)
	state := generateState()

	pkceStatesMu.Lock()
	pkceStates[state] = PKCEState{
		CodeVerifier: codeVerifier,
		RedirectTo:   redirectTo,
		CreatedAt:    time.Now(),
	}
	pkceStatesMu.Unlock()

	cleanupOldStates()

	authURL := fmt.Sprintf("%s/auth/authorize?response_type=code&client_id=%s&redirect_uri=%s&state=%s&code_challenge=%s&code_challenge_method=S256&scope=profile%%20email",
		config.IndikoURL,
		url.QueryEscape(config.ClientID),
		url.QueryEscape(config.RedirectURI),
		state,
		codeChallenge,
	)

	http.Redirect(w, r, authURL, http.StatusTemporaryRedirect)
}

func handleCallback(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	state := r.URL.Query().Get("state")

	if code == "" || state == "" {
		http.Error(w, "Missing code or state", http.StatusBadRequest)
		return
	}

	pkceStatesMu.Lock()
	pkceState, ok := pkceStates[state]
	if ok {
		delete(pkceStates, state)
	}
	pkceStatesMu.Unlock()

	if !ok {
		http.Error(w, "Invalid state", http.StatusBadRequest)
		return
	}

	if time.Since(pkceState.CreatedAt) > 10*time.Minute {
		http.Error(w, "State expired", http.StatusBadRequest)
		return
	}

	tokenResp, err := exchangeCode(code, pkceState.CodeVerifier)
	if err != nil {
		log.Printf("Token exchange failed: %v", err)
		http.Error(w, "Authentication failed", http.StatusInternalServerError)
		return
	}

	session := Session{
		UserID:    tokenResp.Me,
		Name:      tokenResp.Profile.Name,
		Email:     tokenResp.Profile.Email,
		ExpiresAt: time.Now().Add(time.Duration(config.SessionMaxAge) * time.Second),
	}

	if err := setSession(w, &session); err != nil {
		log.Printf("Failed to set session: %v", err)
		http.Error(w, "Failed to create session", http.StatusInternalServerError)
		return
	}

	http.Redirect(w, r, pkceState.RedirectTo, http.StatusTemporaryRedirect)
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     "bore_session",
		Value:    "",
		Path:     "/",
		Domain:   config.CookieDomain,
		MaxAge:   -1,
		Secure:   config.CookieSecure,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})

	redirectTo := r.URL.Query().Get("redirect")
	if redirectTo == "" {
		redirectTo = "https://" + config.CookieDomain[1:]
	}

	http.Redirect(w, r, redirectTo, http.StatusTemporaryRedirect)
}

func exchangeCode(code, codeVerifier string) (*TokenResponse, error) {
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("code", code)
	data.Set("client_id", config.ClientID)
	data.Set("redirect_uri", config.RedirectURI)
	data.Set("code_verifier", codeVerifier)
	if config.ClientSecret != "" {
		data.Set("client_secret", config.ClientSecret)
	}

	resp, err := http.PostForm(config.IndikoURL+"/auth/token", data)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("token endpoint returned %d: %s", resp.StatusCode, string(body))
	}

	var tokenResp TokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, err
	}

	return &tokenResp, nil
}

func getSession(r *http.Request) (*Session, error) {
	cookie, err := r.Cookie("bore_session")
	if err != nil {
		return nil, err
	}

	var session Session
	if err := secureCookie.Decode("bore_session", cookie.Value, &session); err != nil {
		return nil, err
	}

	return &session, nil
}

func setSession(w http.ResponseWriter, session *Session) error {
	encoded, err := secureCookie.Encode("bore_session", session)
	if err != nil {
		return err
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "bore_session",
		Value:    encoded,
		Path:     "/",
		Domain:   config.CookieDomain,
		MaxAge:   config.SessionMaxAge,
		Secure:   config.CookieSecure,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})

	return nil
}

func extractSubdomain(host string) string {
	host = strings.Split(host, ":")[0]
	baseDomain := strings.TrimPrefix(config.CookieDomain, ".")
	if !strings.HasSuffix(host, baseDomain) {
		return ""
	}
	subdomain := strings.TrimSuffix(host, "."+baseDomain)
	if subdomain == host || subdomain == "" {
		return ""
	}
	return subdomain
}

func getProxyConf(subdomain string) *ProxyConf {
	proxyCacheMu.RLock()
	conf, ok := proxyCache[subdomain]
	proxyCacheMu.RUnlock()

	if ok {
		return conf
	}

	refreshProxyCache()

	proxyCacheMu.RLock()
	conf = proxyCache[subdomain]
	proxyCacheMu.RUnlock()

	return conf
}

func refreshProxyCache() {
	proxyCacheMu.Lock()
	defer proxyCacheMu.Unlock()

	if time.Since(proxyCacheAt) < 5*time.Second {
		return
	}

	resp, err := http.Get(config.FrpsAPIURL + "/api/proxy/http")
	if err != nil {
		log.Printf("Failed to fetch proxy list: %v", err)
		return
	}
	defer resp.Body.Close()

	var proxyList ProxyListResponse
	if err := json.NewDecoder(resp.Body).Decode(&proxyList); err != nil {
		log.Printf("Failed to decode proxy list: %v", err)
		return
	}

	newCache := make(map[string]*ProxyConf)
	for _, p := range proxyList.Proxies {
		if p.Status != "online" {
			continue
		}

		var conf ProxyConf
		if err := json.Unmarshal(p.Conf, &conf); err != nil {
			continue
		}

		if conf.Subdomain != "" {
			newCache[conf.Subdomain] = &conf
		}
	}

	proxyCache = newCache
	proxyCacheAt = time.Now()
}

func refreshProxyCachePeriodically() {
	ticker := time.NewTicker(30 * time.Second)
	for range ticker.C {
		refreshProxyCache()
	}
}

func generateCodeVerifier() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func generateCodeChallenge(verifier string) string {
	h := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(h[:])
}

func generateState() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func cleanupOldStates() {
	pkceStatesMu.Lock()
	defer pkceStatesMu.Unlock()

	for state, pkce := range pkceStates {
		if time.Since(pkce.CreatedAt) > 15*time.Minute {
			delete(pkceStates, state)
		}
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func decodeKey(keyStr string) []byte {
	keyStr = strings.TrimSpace(keyStr)
	
	// Try standard base64
	if decoded, err := base64.StdEncoding.DecodeString(keyStr); err == nil && len(decoded) >= 32 {
		return decoded[:32]
	}
	
	// Try URL-safe base64
	if decoded, err := base64.URLEncoding.DecodeString(keyStr); err == nil && len(decoded) >= 32 {
		return decoded[:32]
	}
	
	// Try raw base64 (no padding)
	if decoded, err := base64.RawStdEncoding.DecodeString(keyStr); err == nil && len(decoded) >= 32 {
		return decoded[:32]
	}
	
	// Use raw bytes, pad or truncate to 32
	raw := []byte(keyStr)
	if len(raw) >= 32 {
		return raw[:32]
	}
	
	// Pad with zeros if too short
	padded := make([]byte, 32)
	copy(padded, raw)
	return padded
}
