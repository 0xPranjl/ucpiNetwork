//go:build !ucpicli && linux && !muslc && !darwin
// +build !ucpicli,linux,!muslc,!darwin

package api

// #cgo LDFLAGS: -Wl,-rpath,${SRCDIR} -L${SRCDIR} -lgo_cosmwasm
import "C"
