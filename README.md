### Terraform example: Multiple backends with autoscaled managed instance groups behind a global load balancer

![Multiple backends](https://miro.medium.com/max/1557/1*Ta3QLmaGERAhg1O81whT4w.png)

This script creates multiple backend services replicated across multiple regions and zones for high availability and an HTTP global load balancer that distributes traffic to those backends.

###### **Google Cloud Platform Services and Concepts demonstrated:**
###### 1. [Backend Services](https://cloud.google.com/load-balancing/docs/backend-service)
###### 2. [Google Cloud Load Balancing](https://cloud.google.com/load-balancing/)
###### 3. [Managed instance group](https://cloud.google.com/compute/docs/instance-groups/creating-groups-of-managed-instances)
###### 4. [Regional managed instance groups](https://cloud.google.com/compute/docs/instance-groups/distributing-instances-with-regional-instance-groups)
