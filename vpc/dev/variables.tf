variable account_id {
    default = "364082771643"
}

variable region {
    default = "us-west-2"
}

variable environment{
    default = "dev"
}

variable     name {
    default = "dev"
}
variable     vpc_cidr {
    default = "10.8.0.0/16"
}
variable     azs {
    default = [ "us-west-2a","us-west-2b","us-west-2c" ]
}
variable     private_subnets {
    default = ["10.8.16.0/20", "10.8.80.0/20", "10.8.144.0/20"]
}
variable     private_subnet_names {
    default = [ "dev-priv-us-west-2a", "dev-priv-us-west-2b", "dev-priv-us-west-2c" ]
}
    
variable     public_subnets {
    default = ["10.8.0.0/24", "10.8.64.0/24", "10.8.128.0/24"]
}
variable     public_subnet_names {
    default = [ "dev-pub-us-west-2a", "dev-pub-us-west-2b", "dev-pub-us-west-2c" ]
}
    
variable     db_subnets {
    default = ["10.8.32.0/26", "10.8.96.0/26", "10.8.160.0/26"]
}
variable     db_subnet_names {
    default = [ "dev-db-us-west-2a", "dev-db-us-west-2b", "dev-db-us-west-2c" ]
}
    