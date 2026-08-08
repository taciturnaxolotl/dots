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

// createTangledRepo creates the repo on the knot, then writes the sh.tangled.repo
// record to the PDS so it shows up on tangled.org.
func createTangledRepo(cfg config, name, description string) error {
	creds, err := loadCredentials(cfg.credentialsFile)
	if err != nil {
		return err
	}

	pds, err := resolvePDS(cfg.plcID)
	if err != nil {
		return fmt.Errorf("failed to resolve PDS for %s: %w", cfg.plcID, err)
	}

	var session struct {
		AccessJwt string `json:"accessJwt"`
		DID       string `json:"did"`
	}
	err = call(http.MethodPost, pds+"/xrpc/com.atproto.server.createSession", "",
		map[string]string{"identifier": creds.Identifier, "password": creds.Password}, &session)
	if err != nil {
		return fmt.Errorf("failed to authenticate with PDS: %w", err)
	}

	authURL := fmt.Sprintf("%s/xrpc/com.atproto.server.getServiceAuth?aud=did:web:%s&exp=%d&lxm=sh.tangled.repo.create",
		pds, url.QueryEscape(cfg.knotHost), time.Now().Add(time.Minute).Unix())
	var serviceAuth struct {
		Token string `json:"token"`
	}
	if err := call(http.MethodGet, authURL, session.AccessJwt, nil, &serviceAuth); err != nil {
		return fmt.Errorf("failed to get service auth token: %w", err)
	}

	rkey := strings.ToLower(name)
	var knot struct {
		RepoDID string `json:"repoDid"`
	}
	err = call(http.MethodPost, "https://"+cfg.knotHost+"/xrpc/sh.tangled.repo.create", serviceAuth.Token,
		map[string]string{"rkey": rkey, "name": name, "defaultBranch": cfg.branch}, &knot)
	if err != nil {
		return fmt.Errorf("failed to create repo on knot: %w", err)
	}
	if knot.RepoDID == "" {
		return fmt.Errorf("knot returned no repoDid")
	}

	record := map[string]any{
		"$type":     "sh.tangled.repo",
		"knot":      cfg.knotHost,
		"repoDid":   knot.RepoDID,
		"name":      name,
		"createdAt": time.Now().UTC().Format("2006-01-02T15:04:05Z"),
	}
	if description != "" {
		record["description"] = description
	}

	err = call(http.MethodPost, pds+"/xrpc/com.atproto.repo.createRecord", session.AccessJwt, map[string]any{
		"repo":       session.DID,
		"collection": "sh.tangled.repo",
		"rkey":       rkey,
		"record":     record,
	}, nil)
	if err != nil {
		return fmt.Errorf("failed to write record to PDS: %w", err)
	}
	return nil
}
