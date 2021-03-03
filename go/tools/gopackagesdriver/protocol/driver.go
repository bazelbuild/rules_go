// Copyright 2021 The Bazel Go Rules Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package protocol

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"strings"
)

// Driver is the gopackagesdriver implementation
type Driver func(cfg Request, patterns ...string) (*Response, error)

// Run implements the gopackagesdriver protocol.
// It reads a DriverRequest from stdin, passes the request to driver, and
// writes the response to stdout.
// If driver returns an error, Run will terminate the process.
func Run(driver Driver) {
	cleanup := func() error { return nil }
	if logfile := os.Getenv("GOPACKAGESDRIVER_LOGFILE"); logfile != "" {
		f, err := os.OpenFile(logfile, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
		if err != nil {
			log.Fatalf("couldn't open log file: %s", err)
		}
		errorWriter := io.MultiWriter(f, os.Stderr)
		cleanup = f.Close
		log.SetOutput(errorWriter)
		log.SetFlags(log.Lshortfile | log.Ldate | log.Ltime)
	}

	defer cleanup()

	wd, _ := os.Getwd()
	targets := strings.Join(os.Args[1:], " ")
	if len(targets) > 1000 {
		targets = targets[:998] + "..."
	}
	log.Printf("%v: %v", wd, targets)

	// Make sure any panic goes to the logfile.
	defer func() {
		if err := recover(); err != nil {
			log.Panic(err)
		}
	}()

	if err := run(driver, os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(driver Driver, args []string) error {
	reqData, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		return err
	}
	var req Request
	if err := json.Unmarshal(reqData, &req); err != nil {
		return fmt.Errorf("could not unmarshal driver request: %v", err)
	}

	resp, err := driver(req, args...)
	if err != nil {
		return err
	}

	if os.Getenv("GOPACKAGESDRIVER_DUMP_RESPONSE") != "" {
		respDebug, _ := json.MarshalIndent(resp, "", "  ")
		log.Println("response:", string(respDebug))
	}
	respData, err := json.Marshal(resp)
	if err != nil {
		return fmt.Errorf("could not marshal driver response: %v", err)
	}
	_, err = os.Stdout.Write(respData)
	if err != nil {
		return err
	}

	log.Printf(" -> %d packages, %d roots", len(resp.Packages), len(resp.Roots))

	return nil

}

// GetEnv returns a value from cfg.Env, or def if the value isn't found.
func GetEnv(cfg *Request, name, def string) string {
	prefix := name + "="
	result := def
	for _, env := range cfg.Env {
		if value := strings.TrimPrefix(env, prefix); value != env {
			result = value
		}
	}
	return result
}
