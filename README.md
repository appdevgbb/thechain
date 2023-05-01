# Never Break the Chain: Securing the Container Supply Chain with Notary, TUF, and Gatekeeper

The lack of software supply chain security has become a common attack vector for malicious code, and it is important to ensure secure and controlled processes when working with containers in Kubernetes. Digital signatures, such as those provided by Notary, Gatekeeper, and Ratify, can be used to ensure code integrity. This article compares these technologies and provides a demo on how to use them in a typical CI/CD process, including enforcement by policy in Kubernetes clusters, to prevent malicious code deployment.

Recently we have seen challenges in the global consumer supply chain while the SolarWinds hack highlighted software supply chain weakness. The lack of software supply chain security has become a common attack vector for malicious code. When working with containers, it is important to ensure that processes are secure and controlled and be mindful that this is a multifaceted concern. While we can use a number of tools to scan for vulnerabilities, using digital signatures is a great way to ensure your code is exactly what is intended. Today, we will compare different options for signing container images and work through a demo using Notary, Gatekeeper, and Ratify. Notary is an open source project designed on TUF (The Update Framework) which is a specification for managing trusted application code. Gatekeeper is a customizable admission webhook for Kubernetes that enforces policies executed by the Open Policy Agent (OPA). Ratify is a workflow engine that coordinates the verification of different supply chain objects for an image as per a given policy. We will show how to use these technologies in a typical CI/CD process including enforcement by policy in Kubernetes clusters. Will the hacker be able to get malicious code deployed to our clusters? Tune in to find out!

## Target Audience
The target audience for this tutorial is developers and security minded professionals looking for approaches on how to harden the software supply chain.

## Solution Details

* Configure the Terraform template.
* Install Notation.
* Install the Key Vault Plugin.
* Add the signing certificate to Notation.
* Build and sign a container image.
* Destroy the infrastructure.

## Prerequisites
* For this workshop, you will need:

* An Azure account
* The Terraform binary
* Kubectl
* Another option is to use the Cloud Shell on Azure at https://shell.azure.com

The examples here will use Microsoft Azure. For more information please refer to the Before You Begin section.

While Azure is used for basic infrastructure requirements most of the lessons learned in this tutorial can be applied to other platforms that support Kubernetes.