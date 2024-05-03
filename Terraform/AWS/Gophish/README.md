# Gophish instance

Gophish installed on in a container on an EC2 instance in an ASG.

### Usage

- Connect to instance using System Manager Session Manager.

- After instance is running change Ingress rules in Security Group to allow desired IP/CIDR to access to admin Console.
&nbsp;
&nbsp;

### Features

- Gophish is installed in a container.

- The initial admin password for Gophish is in the container logs:

      $ grep admin /var/lib/docker/containers/<ID>/<ID>-json.log

- The latest Amazon Linux 2023 Minimal AMI is used for the Gophish instance.

- The Gophish instance is not accessible via SSH; only the System Manager Session Manager can be used.




