module github.com/diktyo-io/networktopology-api

go 1.16

require (
	github.com/gogo/protobuf v1.3.2
	k8s.io/api v0.22.3
	k8s.io/apimachinery v0.22.3
	k8s.io/client-go v0.22.3 // indirect
	k8s.io/code-generator v0.22.3
)

replace github.com/diktyo-io/networktopology-api => ../networktopology-api
