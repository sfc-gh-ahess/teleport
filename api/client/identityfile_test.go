/*
Copyright 2021 Gravitational, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/

package client

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

// TestIdentityFileBasics verifies basic profile operations such as
// load/store and setting current.
func TestIdentityFileBasics(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "file")
	writeIDFile := &IdentityFile{
		PrivateKey: []byte("-----BEGIN RSA PRIVATE KEY-----\nkey\n-----END RSA PRIVATE KEY-----\n"),
		Certs: Certs{
			SSH: []byte("ssh ssh-cert"),
			TLS: []byte("-----BEGIN CERTIFICATE-----\ntls-cert\n-----END CERTIFICATE-----\n"),
		},
		CACerts: CACerts{
			SSH: [][]byte{[]byte("@cert-authority ssh-cacerts")},
			TLS: [][]byte{[]byte("-----BEGIN CERTIFICATE-----\ntls-cacerts\n-----END CERTIFICATE-----\n")},
		},
	}

	// Write identity file
	err := WriteIdentityFile(writeIDFile, path)
	require.NoError(t, err)

	// Read identity file
	readIDFile, err := ReadIdentityFile(path)
	require.NoError(t, err)

	// Check that read and write values are equal
	require.Equal(t, writeIDFile, readIDFile)
}
