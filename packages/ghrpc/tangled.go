package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

type credentials struct {
	Identifier string
	Password   string
}

// loadCredentials reads the agenix env file (ACCOUNT1 / ACCOUNT1_PASSWORD).
func loadCredentials(path string) (credentials, error) {
	f, err := os.Open(path)
	if err != nil {
		return credentials{}, err
	}
	defer f.Close()

	var c credentials
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		line = strings.TrimPrefix(line, "export ")
		key, value, found := strings.Cut(line, "=")
		if !found || strings.HasPrefix(key, "#") {
			continue
		}
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		switch strings.TrimSpace(key) {
		case "ACCOUNT1":
			c.Identifier = value
		case "ACCOUNT1_PASSWORD":
			c.Password = value
		}
	}
	if c.Identifier == "" || c.Password == "" {
		return c, fmt.Errorf("no ACCOUNT1 credentials in %s", path)
	}
	return c, scanner.Err()
}

var httpClient = &http.Client{Timeout: 30 * time.Second}

// call performs a JSON request and decodes the response into out. XRPC errors
// come back as {error, message}, so a 4xx carries a usable reason.
func call(method, endpoint, token string, body any, out any) error {
	var reader io.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(encoded)
	}

	req, err := http.NewRequest(method, endpoint, reader)
	if err != nil {
		return err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	payload, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	var apiErr struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	_ = json.Unmarshal(payload, &apiErr)
	if apiErr.Error != "" {
		if apiErr.Message != "" {
			return fmt.Errorf("%s: %s", apiErr.Error, apiErr.Message)
		}
		return fmt.Errorf("%s", apiErr.Error)
	}
	if resp.StatusCode >= 400 {
		return fmt.Errorf("%s", resp.Status)
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(payload, out)
}

// resolvePDS finds the PDS service endpoint for a PLC identity.
func resolvePDS(plcID string) (string, error) {
	var doc struct {
		Service []struct {
			Type            string `json:"type"`
			ServiceEndpoint string `json:"serviceEndpoint"`
		} `json:"service"`
	}
	if err := call(http.MethodGet, "https://plc.directory/"+plcID, "", nil, &doc); err != nil {
		return "", err
	}
	for _, s := range doc.Service {
		if s.Type == "AtprotoPersonalDataServer" {
			return strings.TrimSuffix(s.ServiceEndpoint, "/"), nil
		}
	}
	return "", fmt.Errorf("no PDS in PLC document")
}

// atSession is a logged-in PDS session that can mint knot service tokens.
type atSession struct {
	pds       string
	DID       string `json:"did"`
	AccessJwt string `json:"accessJwt"`
}

func login(cfg config) (*atSession, error) {
	creds, err := loadCredentials(cfg.credentialsFile)
	if err != nil {
		return nil, err
	}
	pds, err := resolvePDS(cfg.plcID)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve PDS for %s: %w", cfg.plcID, err)
	}
	s := &atSession{pds: pds}
	err = call(http.MethodPost, pds+"/xrpc/com.atproto.server.createSession", "",
		map[string]string{"identifier": creds.Identifier, "password": creds.Password}, s)
	if err != nil {
		return nil, fmt.Errorf("failed to authenticate with PDS: %w", err)
	}
	return s, nil
}

// knotCall POSTs an XRPC procedure to the knot under a service token scoped to nsid.
func (s *atSession) knotCall(knotHost, nsid string, body, out any) error {
	authURL := fmt.Sprintf("%s/xrpc/com.atproto.server.getServiceAuth?aud=did:web:%s&exp=%d&lxm=%s",
		s.pds, url.QueryEscape(knotHost), time.Now().Add(time.Minute).Unix(), nsid)
	var auth struct {
		Token string `json:"token"`
	}
	if err := call(http.MethodGet, authURL, s.AccessJwt, nil, &auth); err != nil {
		return fmt.Errorf("failed to get service auth token: %w", err)
	}
	return call(http.MethodPost, "https://"+knotHost+"/xrpc/"+nsid, auth.Token, body, out)
}

type createRepoInput struct {
	Name          string `json:"name"`
	DefaultBranch string `json:"defaultBranch"`
	Description   string `json:"description,omitempty"`
}

// maxDescriptionRunes matches the cap tangled's own migrator applies.
const maxDescriptionRunes = 140

// createTangledRepo creates the repo on the knot, then declares it on the PDS so tangled.org lists it.
func createTangledRepo(cfg config, name, description string) error {
	session, err := login(cfg)
	if err != nil {
		return err
	}

	input := createRepoInput{Name: name, DefaultBranch: cfg.branch}
	if runes := []rune(strings.TrimSpace(description)); len(runes) > 0 {
		input.Description = string(runes[:min(len(runes), maxDescriptionRunes)])
	}
	var repo struct {
		DID string `json:"did"`
	}
	if err := session.knotCall(cfg.knotHost, "org.tangled.repo.createRepo", input, &repo); err != nil {
		return fmt.Errorf("failed to create repo on knot: %w", err)
	}
	if repo.DID == "" {
		return fmt.Errorf("knot returned no repo did")
	}

	err = call(http.MethodPost, session.pds+"/xrpc/com.atproto.repo.createRecord", session.AccessJwt, map[string]any{
		"repo":       session.DID,
		"collection": "org.tangled.repo.declaration",
		"rkey":       strings.ToLower(name), // the knot derives its rkey the same way
		"record": map[string]any{
			"$type":     "org.tangled.repo.declaration",
			"repo":      repo.DID,
			"createdAt": time.Now().UTC().Format(time.RFC3339),
		},
	}, nil)
	if err == nil {
		return nil
	}

	// an undeclared knot repo would make every retry fail with a name conflict
	if rbErr := session.knotCall(cfg.knotHost, "org.tangled.repo.deleteRepo", map[string]string{"repo": repo.DID}, nil); rbErr != nil {
		return fmt.Errorf("failed to write record to PDS: %w (and rolling back %s failed: %v)", err, repo.DID, rbErr)
	}
	return fmt.Errorf("failed to write record to PDS: %w", err)
}
