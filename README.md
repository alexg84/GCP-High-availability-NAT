# High-availability-NAT

For higher resiliency, you place each gateway in a separate managed instance group with size 1 and attach a simple health
check to ensure that the gateways will automatically restart if they fail.
The gateways are in separate instance groups so they'll have a static external IP attached to the instance template.
You provision three n1-standard-2 NAT gateways in this example, but you can use any other number or size of gateway that you
want. 
For example, n1-standard-2 instances are capped at 4 Gbps of network traffic; if you need to handle a higher volume of traffic,
you might choose n1-standard-8s.

This sulution will create:
network = example-vpc
subnets = example-east
in region = us-east1 

https://cloud.google.com/vpc/docs/special-configurations#multiple-natgateways
