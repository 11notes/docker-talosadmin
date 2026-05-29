package main

import (
	"os"
	"github.com/11notes/go-eleven"
)

func main(){
	password, err := eleven.Container.GetSecret("GOVC_PASSWORD", "GOVC_PASSWORD_FILE")
	if err != nil {
		eleven.LogFatal("you must set GOVC_PASSWORD or GOVC_PASSWORD_FILE!")
	}

	eleven.Util.ExecAbsolute("/usr/local/bin/govc.org", os.Args, []string{"GOVC_PASSWORD=" + password})
}