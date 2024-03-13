## This repository provisions a Cloud Run echo container, GCP GLB fronted by Cloudflare and secured by a mTLS

### Traffic flow  - Client -> Cloudflare -> GLB -> CloudRun Nginx echo container

Communication between CloudFlare and GCP GLB (origin) is secured via mTLS by using a CloudFlare provided certificate that is loaded into the trust store of the GCP GLB.

## Requirements to run this

1. GCP project - project_id
2. Cloudflare API token with proper permissions - cloudflare_api_token
3. Cloudflare DNS zone ID - cloudflare_zone_id
4. A domain that has been pointed at cloudflare - change that in locals.tf

You can pass the above variables in during terraform apply or use environment variables

After deployment you will get a 403 from CloudRun untill you turn on IAP for the back-end

Diagram of the solution

![Alt text](/images/Cloudflare.jpeg)

