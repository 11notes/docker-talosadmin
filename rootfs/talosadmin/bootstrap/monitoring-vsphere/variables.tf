variable "vcenter_endpoints" {
  type = list(object({
    name = string
    endpoint = string
    username = string
    password = string
    env_var = string
  }))
  description = "list of vcenters"
  default = [
    {
      name = "datacenter_east"
      endpoint = "https://vc-east.internal.net/sdk"
      username = "mon-prometheus@vsphere.local"
      password = "***************"
      env_var = "VCENTER_PASSWORD_EAST"
    }
  ]
}