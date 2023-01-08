variable "project_id" {
    type = string
    default = "xxxxxxx"
}

variable "sa" {
    type = string
    default = "compute-engine-sa"
}

variable "data_disk_name" {
    type = string
    default = "webapp_data_disk"
}

variable "boot_disk_name" {
    type = string
    default = "webapp_boot_disk"
}

variable "subnet" {
    type = string
    default = ""
}
