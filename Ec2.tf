resource "aws_key_pair" "assesment-key" {
key_name = "assesment-key"
public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_instance" "master" {
ami = "ami-006f82a1d5a27da54"
instance_type = "c7i-flex.large"
subnet_id = aws_subnet.public1.id
vpc_security_group_ids = [aws_security_group.web_sg.id]
key_name = aws_key_pair.assesment-key.key_name
root_block_device {
volume_size = 25
volume_type = "gp3"
}
 
tags = {
Name = "assesment-master"
}
}
resource "aws_instance" "worker-1" {
ami = "ami-006f82a1d5a27da54"
instance_type = "c7i-flex.large"
subnet_id = aws_subnet.public1.id
vpc_security_group_ids = [aws_security_group.web_sg.id]
key_name = aws_key_pair.assesment-key.key_name
root_block_device {
volume_size = 10
volume_type = "gp3"
}
 
tags = {
Name = "assesment-worker-1"
}
}
resource "aws_instance" "worker-2" {
ami = "ami-006f82a1d5a27da54"
instance_type = "c7i-flex.large"
subnet_id = aws_subnet.public1.id
vpc_security_group_ids = [aws_security_group.web_sg.id]
key_name = aws_key_pair.assesment-key.key_name
root_block_device {
volume_size = 10
volume_type = "gp3"
}
 
tags = {
Name = "assesment-worker-2"
}
}
