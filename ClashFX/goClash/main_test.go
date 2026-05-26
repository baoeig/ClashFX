package main

import "testing"

func TestSplitTunRouteExcludeEntriesAcceptsLocalhost(t *testing.T) {
	prefixes, domains, invalid := splitTunRouteExcludeEntries("127.0.0.1, localhost, *.local, +.example.com")

	if len(invalid) != 0 {
		t.Fatalf("unexpected invalid entries: %v", invalid)
	}
	if got, want := len(prefixes), 1; got != want {
		t.Fatalf("prefix count = %d, want %d", got, want)
	}
	if got, want := domains, []string{"localhost", "*.local", "+.example.com"}; len(got) != len(want) {
		t.Fatalf("domains = %v, want %v", got, want)
	} else {
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("domains = %v, want %v", got, want)
			}
		}
	}
}

func TestSplitTunRouteExcludeEntriesAcceptsLegacyWildcards(t *testing.T) {
	prefixes, domains, invalid := splitTunRouteExcludeEntries("192.168.*, 10.*, 172.16.*, 172.31.*")

	if len(invalid) != 0 {
		t.Fatalf("unexpected invalid entries: %v", invalid)
	}
	if len(domains) != 0 {
		t.Fatalf("domains = %v, want none", domains)
	}
	want := []string{"192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/16", "172.31.0.0/16"}
	if len(prefixes) != len(want) {
		t.Fatalf("prefixes = %v, want %v", prefixes, want)
	}
	for i := range want {
		if prefixes[i].String() != want[i] {
			t.Fatalf("prefixes = %v, want %v", prefixes, want)
		}
	}
}

func TestSplitTunRouteExcludeEntriesRejectsInvalidText(t *testing.T) {
	_, _, invalid := splitTunRouteExcludeEntries("not valid")

	if got, want := invalid, []string{"not valid"}; len(got) != len(want) || got[0] != want[0] {
		t.Fatalf("invalid = %v, want %v", got, want)
	}
}
