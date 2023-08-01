package main

import (
	"bytes"
	"io"
	"log"
	"net/http"
	_ "net/http/pprof"
)

func render(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}

	src, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("error reading body: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	var buf bytes.Buffer
	if _, err := buf.Write(src); err != nil {
		log.Printf("error writing response: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if _, err := io.Copy(w, &buf); err != nil {
		log.Printf("error writing response: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

func main() {
	http.HandleFunc("/render", render)
	log.Printf("Serving on port 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
