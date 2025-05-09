# install-argocd

<!-- TOC -->

- [install-argocd](#install-argocd)
- [Requirements](#requirements)
- [Configure ArgoCD](#configure-argocd)
- [References:](#references)

<!-- TOC -->

# Requirements

- Install all packages and binaries following the instructions on the [REQUIREMENTS.md](../../REQUIREMENTS.md) file.
- Create the cluster following the instructions on the [README.md](../../README.md#create-the-cluster-and-deploy-applications) file.

# Configure ArgoCD

List the resources.

```bash
kubectl get all -n argocd
```

If needs add entry in ``/etc/hosts`` file:

```bash
# Add entry in /etc/hosts for argocd
export IP=$(kubectl get ing argocd -n argocd -o json | jq -r .status.loadBalancer.ingress[].ip)
sudo grep -qxF "$IP  argocd.mycompany.com" /etc/hosts || sudo sh -c "echo '$IP  argocd.mycompany.com' >> /etc/hosts"
```

Open the browser and access the URL: https://argocd.mycompany.com/

The default login is **admin** and password **changeme**

Add Github repository in URL: 

- https://argocd.mycompany.com/settings/repos?addRepo=true

> See the doc https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens to generate a API token

Add github repository using this informations:

- Choose your connection method: HTTPS
- Type: git
- Project: default
- Repository URL: https://github.com/aeciopires/learning-victoriametrics.git

Add gitlab repository using this informations:

- Choose your connection method: HTTPS
- Type: git
- Project: default
- Repository URL: https://gitlab.com/aeciopires/kube-pires.git

# References:

- https://medium.com/globant/using-multiple-sources-for-a-helm-chart-deployment-in-argocd-cf3cd2d598fc
- https://artifacthub.io/packages/helm/argo/argo-cd
- https://blog.aeciopires.com/usando-o-argo-cd-para-implementar-a-abordagem-gitops-nos-clusters-kubernetes/
- https://argo-cd.readthedocs.io/en/stable/
- https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/
- https://argo-cd.readthedocs.io/en/latest/operator-manual/ingress/
- https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
- https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/
