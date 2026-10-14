# Classic MIWI deploy

This guide is the operator command path. Agents use [`clusters/aro-classic-miwi/AGENTS.md`](../../clusters/aro-classic-miwi/AGENTS.md) for done-when gates.

## 0. Unset `TF_VAR_*`

```bash
env | grep '^TF_VAR_' || true
```

If any are set, unset them or align `clusters/aro-classic-miwi/terraform.tfvars` before `make cluster.*`.

## 1. Plan and apply

```bash
make setup
cp clusters/aro-classic-miwi/terraform.tfvars clusters/aro-classic-miwi/terraform.tfvars.local
# Edit location, domain, pull_secret_path

make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply
```

Apply is long-running (often 60–90 minutes). Prefer tmux.

## 2. Kubeconfig

```bash
make cluster.aro-classic-miwi.kubeconfig
```

Uses `az aro list-admin-credentials` (Classic admin kubeconfig).

## 3. Second apply (OIDC issuer)

After the cluster exists, copy the issuer into tfvars:

```bash
terraform -chdir=terraform output -raw oidc_issuer_url
```

Set `oidc_issuer_url` in `clusters/aro-classic-miwi/terraform.tfvars`, then:

```bash
make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.platform
```

`platform.json` is gitignored under `clusters/aro-classic-miwi/`.

## 4. BGP Cloud Connector (out of band)

Install the engineering operator build (see [diana-sari/aro-virt-bgp](https://github.com/diana-sari/aro-virt-bgp) for the validated image pin).

Label router workers on the **MachineSet** template (`bgp_router: "true"`), not only on Nodes.

Render manifests:

```bash
export MACHINE_API_CLIENT_ID="$(jq -r .machine_api_client_id clusters/aro-classic-miwi/platform.json)"
export AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export AZURE_RESOURCE_GROUP="$(jq -r .resource_group_name clusters/aro-classic-miwi/platform.json)"
export AZURE_ROUTE_SERVER_NAME="$(jq -r .route_server_name clusters/aro-classic-miwi/platform.json)"
./scripts/render-bgp.sh | oc apply -f -
```

## 5. Destroy

```bash
DESTROY_CONFIRM=yes make cluster.aro-classic-miwi.destroy
```

Destroy deletes the AzAPI cluster first, then the remaining Terraform resources.
