################################################################################
# Default Security Group - EC2.2 Security Hub Fix
# VPC default security groups should not allow inbound or outbound traffic
################################################################################

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Take over management of the default security group and remove all rules
# This fixes AWS Security Hub finding EC2.2
resource "aws_default_security_group" "default" {
  vpc_id = data.aws_vpc.default.id

  # By not specifying any ingress or egress blocks, all rules are removed
  # This ensures the default security group has no inbound or outbound rules

  tags = merge(local.common_tags, {
    Name        = "default-sg-restricted"
    Description = "Default security group with all rules removed - EC2.2 compliance"
  })
}
