package state

import "sync"

type SystemState struct {
	mu    sync.RWMutex
	rele6 bool
	rele7 bool
}

func NewSystemState() *SystemState {
	return &SystemState{}
}

func (s *SystemState) SetRelay6(open bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rele6 = open
}

func (s *SystemState) SetRelay7(open bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rele7 = open
}

func (s *SystemState) SetBoth(relay6, relay7 bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rele6 = relay6
	s.rele7 = relay7
}

func (s *SystemState) Snapshot() (bool, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.rele6, s.rele7
}
