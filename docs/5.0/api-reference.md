---
title: Teleport API Reference
description: The detailed guide to Teleport API
---

# Teleport API Reference

In most cases, you can interact with Teleport using our CLI tools, [tsh](cli-docs.md#tsh) and [tctl](cli-docs.md#tctl). However, there are some scenarios where you may need to interact with Teleport programmatically. For this purpose, you can directly use the same API that `tctl` and `tsh` use.

!!! note

    We are currently working on improving our API Documentation. If you have an API suggestion, [please complete our survey](https://docs.google.com/forms/d/1HPQu5Asg3lR0cu5crnLDhlvovGpFVIIbDMRvqclPhQg/viewform).

## Go Examples

!!! note

    The Go examples below depend on some features and changes that are released in Teleport 5.0.

Below are some code examples that can be used with Teleport to perform a few key tasks.

Before you begin:

- Install [Go](https://golang.org/doc/install) 1.15+ and Setup Go Dev Environment
- Have access to a Teleport Auth server ([quickstart](quickstart.md))

The easiest way to get started with the Teleport API is to clone the [Go Client Example](https://github.com/gravitational/teleport/tree/master/examples/go-client) in our github repo. Follow the README there to quickly authenticate the API with your Teleport Auth Server.

Or if you prefer, follow the Authentication, Go Client, and Go Packages sections below to add the necessary files to a new directory called `/api-examples`. At the end, you should have this file structure:

```
api-examples
+-- api-admin.yaml
+-- certs
|   +-- api-admin.cas
|   +-- api-admin.crt
|   +-- api-admin.key
+-- client.go
+-- go.mod
+-- go.sum
+-- main.go
```

## Authentication

In order to interact with the API, you will need to provision appropriate TLS certificates. In order to provision certificates, you will need to create a user with appropriate permissions. You should only give the API user permissions for what it actually needs.

To quickly get started with the API, you can use this api-admin user. However in production usage, make sure to have stringent permissions in place.

```bash
# Copy and Paste the below and run on the Teleport Auth server.
$ cat > api-admin.yaml <<EOF
{!examples/go-client/api-admin.yaml!}
EOF

$ tctl create -f api-admin.yaml
$ mkdir -p certs
$ tctl auth sign --format=tls --user=api-admin --out=certs/api-admin
```

This should result in three PEM encoded files being generated in the `/certs` directory: `api-admin.crt`, `api-admin.key`, and `api-admin.cas` (certificate, private key, and CA certs respectively).

Move the `/certs` folder into your `/api-examples` folder.

!!! note

    By default, `tctl auth sign` produces certificates with a relatively short lifetime. See our [Kubernetes Section](kubernetes-access.md#using-teleport-kubernetes-with-automation) for more information on automating the signing process for short lived certificates.

    While we encourage you to use short lived certificates, we understand you may not have all the infrastructure to issues and obtain them at the onset. You can use the --ttl flag to extend the lifetime of a certificate in these cases but understand this reduces your security posture

## Go Client

The client below interfaces with the Teleport gRPC API, and relies on the `certs` generated above for TLS.

Add `client.go` into your `/api-examples` folder.

**client.go**

```go
{!examples/go-client/client.go!}
```

## Go Packages

Copy the Teleport module's go.mod below into `/api-examples` and then run `go mod tidy` to slim it down to only what's needed for these api examples.

```
{!go.mod!}
```

## Main file

Add this main file to your `/api-examples` folder. Now you can simply plug in the examples below and then run `go run .` to see them in action.

**main.go**

```go
package main

import (
  "fmt"
  "log"
)

func main() {
  log.Printf("Starting Teleport client...")
  client, err := connectClient()
  if err != nil {
    log.Fatalf("Failed to create client: %v", err)
  }
}
```

## Object Resource

All Teleport resources, such as `Roles` and `Tokens`, share several fields for database management. To keep the documentation below clear, we will refer to these fields as `Resource Fields`.

```go
// Resource is a group of fields that all Teleport resources have
type Resource struct {
  // Kind is a resource kind
  Kind string
  // SubKind is an optional resource sub kind, used in some resources
  SubKind string
  // Version is version
  Version string
  // Metadata is User metadata
  Metadata struct {
    // Name is an object name
    Name string
    // Namespace is object namespace.
    Namespace string
    // Description is object description
    Description string
    // Labels is a set of labels
    Labels map[string]string
    // Expires is a global expiry time header can be set on any resource in the system.
    Expires *time.Time
    // ID is a record ID
    ID int64
  }
}
```

## Roles

Every user in Teleport is assigned a set of [roles](enterprise/ssh-rbac.md#roles). A user's roles defines what actions or resources the user is allowed or denied to access. We offer a wide array of permissions, allowing you to safely and precisely give developers access to the resources they need.

Some of the permissions a role could define include:

- Which SSH nodes a user can or cannot access.
- Ability to replay recorded sessions.
- Ability to update cluster configuration.
- Which UNIX logins a user is allowed to use when logging into servers.

!!! note

    The open source edition of Teleport automatically assigns every user to the built-in `admin` role, but Teleport Enterprise allows administrators to define their own roles with far greater control over the user permissions.

You can manage roles with the Teleport CLI tool [tctl](cli-docs.md#tctl), or programmatically with the RPC calls documented below.

You may want to use the API to manage roles if:

- You want to write a program that can always ensure certain roles exist on your system and do not want to orchestrate `tctl` to do this.
- You want to dynamically create short lived roles.
- You want to dynamically create roles with fields filled that Teleport currently does not support.

### The Role Object

A Teleport `role` is defined by its `Allow` rules, `Deny` rules, and OpenSSH `Options`. We'll break these down piece by piece below.

To see a role example in `yaml` form, look at the the admin role in the [RBAC documentation](enterprise/ssh-rbac.md). You'll notice that the role object below has the same exact nested structure as its `yaml` counterpart.

```go
// RoleV3 represents role resource specification
type RoleV3 struct {
  // Resource Fields are fields that all Teleport resources have - see above
  Resource Fields
  // Spec is the role specification
  Spec RoleSpecV3 struct {
    // Options is for OpenSSH options like agent forwarding.
    Options RoleOptions
    // Allow is the set of conditions evaluated to grant access.
    Allow RoleConditions
    // Deny is the set of conditions evaluated to deny access. Deny takes priority over allow.
    Deny RoleConditions
  }
}
```

**Role Options**

The `RoleOptions` struct defines what OpenSSH actions a user is allowed to use.

```go
// RoleOptions is a set of role options
type RoleOptions struct {
  // ForwardAgent is SSH agent forwarding. default true.
  ForwardAgent Bool
  // MaxSessionTTL defines how long a SSH session can last for.
  MaxSessionTTL Duration
  // PortForwarding defines if the certificate will have "permit-port-forwarding"
  // in the certificate. PortForwarding is true if not set.
  PortForwarding *BoolOption // struct { Value bool } - Nullable boolean
  // CertificateFormat defines the format of the user certificate to allow
  // compatibility with older versions of OpenSSH.
  CertificateFormat string
  // ClientIdleTimeout sets disconnect clients on idle timeout behavior,
  // if set to 0 means do not disconnect, otherwise is set to the idle duration.
  ClientIdleTimeout Duration
  // DisconnectExpiredCert sets disconnect clients on expired certificates.
  DisconnectExpiredCert Bool
  // BPF defines what events to record for the BPF-based session recorder.
  BPF []string
  // PermitX11Forwarding authorizes use of X11 forwarding.
  PermitX11Forwarding Bool
  // MaxConnections defines the maximum number of
  // concurrent connections a user may hold.
  MaxConnections int64
  // MaxSessions defines the maximum number of
  // concurrent sessions per connection.
  MaxSessions int64
}
```

**Role Conditions**

The `RoleConditions` struct allows for precise permission combinations between a role's `Allow` and `Deny` fields.

`Deny` conditions are evaluated first and logically OR'ed. That means that when a user attempts an action, if any of their roles has a deny section matching that action, the user will be denied access. If the user is not denied access, then the `Allow` conditions are evaluated and logically AND'ed. So if a user has any roles with an allow section matching the action, the action will be permitted.

However, this also allows you to take a modular approach to defining roles. Splitting roles up into logical parts will allow you to manage roles for many developers more effectively. It may also be effective to keep your deny and allow conditions in separate roles so that conflicting roles are obvious.

```go
// RoleConditions is a set of conditions that must all match to be allowed or denied access.
type RoleConditions struct {
  // Logins is a list of *nix system logins,  e.g. "root".
  Logins []string
  // Namespaces is a list of namespaces (used to partition a cluster).
  Namespaces []string
  // NodeLabels is a map of node labels (used to dynamically grant access to nodes).
  NodeLabels Labels
  // Rules is a list of rules and their access levels. Rules represents allow or deny rule
  // that is executed to check if user or service have access to resource
  Rules []Rule
  // KubeGroups is a list of kubernetes groups that Teleport users with this role will be
  KubeGroups []string
  // A list of roles that this role can request access to
  Request *AccessRequestConditions // type AccessRequestConditions struct { Roles []string }
  // KubeUsers is an optional list of kubernetes users that Teleport users with this role will be
  KubeUsers []string
  // AppLabels is a map of labels used as part of the RBAC system.
  AppLabels Labels
  // ClusterLabels is a map of node labels (used to dynamically grant access to clusters).
  ClusterLabels Labels
}
```

**Labels**

```go
type Label map[string]utils.Strings
```
Labels are arbitrary key-value pairs that can be used to differentiate nodes, apps, or leaf clusters by key attributes. For example, `NodeLabels` might have the key `environment`, with its value set to `development`, `staging`, or `production`, according to the node's location.

```go
services.Labels{"environment": utils.Strings{"development", "staging"}}
```

Depending on which field you put these labels in, you can allow/deny access to any nodes, apps, or leaf clusters with the given labels. These labels can be very useful in systems where you need to carefully manage access across many clusters, e.g. if you are managing clusters for several outside groups.

**Rules**

The primary building blocks of a rule are its resources and verbs. The optional `Where` and `Actions` fields can be used for more advanced rules.

```go
type Rule struct {
  // Resources is a list of resources
  Resources []string
  // Verbs is a list of verbs
  Verbs []string
  // Where specifies optional advanced matcher
  Where string
  // Actions specifies optional actions taken when this rule matches
  Actions []string
}

```

Here's an example of a rule describing `read only` verbs applied to the SSH `session` resource. Depending on if it's under `Allow` or `Deny`, it means "allow/deny users of this role the ability to read or list active SSH sessions".

```go
services.NewRule(
  services.KindSession,
  services.RO(), // helper function to get 'read only' verbs ("list" and "read")
)
```

**Resources**

Resources include values like the ones below, and much more. The rest of the Teleport resources can be found in the `services` package.

```go
KindRole          = "role"
KindAccessRequest = "access_request"
KindToken         = "token"
KindCertAuthority = "cert_authority"
```

**Verbs**

These are all of the possible resource values, which can be found in the `services` package.

```go
VerbList          = "list"
VerbCreate        = "create"
VerbRead          = "read"
// readnosecrets prevents secrets on some resources from being read.
// For example, retrieving the Certificate Authority will return it without its private keys.
VerbReadNoSecrets = "readnosecrets"
VerbUpdate        = "update"
VerbDelete        = "delete"
VerbRotate        = "rotate"
```

There are also helper functions `RW()`, `RO()`, and `ReadNoSecrets()` in the `services` package to quickly get read/write verbs, read only verbs, and read only verbs with `readnosecrets` respectively.

### Retrieve Role

This is the equivalent of `tctl get role/admin`.

```go
role, err := client.GetRole("admin")
if err != nil {
  return err
}
```

### Create Role

You can use the `UpsertRole` RPC to programmatically create a new role. This is the equivalent of `tctl create -f auditor-role.yaml`, where the `-f` flag signals to overwrite the auditor role if it exists already.

Suppose you wanted to create a role for an auditor that could view all sessions, but could not access any servers. Using `tctl`, you would first create a role that allows reading and listing of the session resource like below. In addition, the user is explicitly denied access to all nodes in the deny block.

```
$ cat << EOF > /tmp/auditor-role.yaml
kind: role
version: v3
metadata:
  name: auditor
spec:
  options:
    max_session_ttl: 8h
  allow:
    rules:
    - resources: [session]
      verbs: [list, read]
  deny: {}
    node_labels: '*': '*'
EOF
$ tctl create -f /tmp/auditor-role.yaml
```

To do something similar with the API:

```go
role, err := services.NewRole("auditor", services.RoleSpecV3{
  Options: services.RoleOptions{
    MaxSessionTTL: services.Duration(time.Hour),
  },
  Allow: services.RoleConditions{
    Logins: []string{"auditor"},
    Rules: []services.Rule{
      services.NewRule(services.KindSession, services.RO()),
    },
  },
  Deny: services.RoleConditions{
    NodeLabels: services.Labels{"*": []string{"*"}},
  },
})
if err != nil {
  return err
}
if err = client.UpsertRole(ctx, role); err != nil {
  return err
}
```

### Update Role

The `UpsertRole` RPC can also be used to update an existing role. You can change a role's field with the setter functions available, or directly.

```go
// retrieve role
role, err := client.GetRole("auditor")
if err != nil {
  return err
}

// update the auditor role to be expired
role.SetExpiry(time.Now())
if err := client.UpsertRole(ctx, role); err != nil {
  return err
}
```

### Delete Role

This is the equivalent of `tctl rm auditor-role.yaml`.

```go
if err := client.DeleteRole(ctx, "auditor"); err != nil {
  return err
}
```

## Tokens

Teleport is a "clustered" system, meaning it only allows access to hosts that had been previously granted cluster membership. To achieve this, a cluster has "join tokens" which can be shared to extend trust.

A remote host can exchange one of these tokens with the cluster's auth server to receive signed certificates and become a trusted Teleport host (auth, node, proxy, app, or kubernetes server). Likewise, a remote Teleport cluster can exchange a token to become a leaf cluster in a [trusted cluster](admin-guide.md#trusted-clusters).

These tokens can be predefined static tokens, or dynamic tokens with a short life time. The latter can be generated by `tctl` or this API, and is more secure.

You may want to use this API to manage tokens if:

- You have a program that dynamically adds new hosts to clusters
- You want to programmatically add leaf clusters to a trusted cluster

### The Token Object

The Token has a Roles field, which defines what roles this token provides in the root cluster.

```go
type ProvisionTokenV2 struct {
  // Resource Fields are fields that all Teleport resources have - see above
  Resource Fields
  // Spec is the token specification
  Spec ProvisionTokenSpecV2 struct {
    // Roles is a list of roles associated with the token
    Roles []teleport.Role // teleport.Role is a custom string type
  }
}
```

**Roles**

Not to be confused with [RBAC Roles](api-reference.md#roles), the `Roles` field on a Token determines what server roles a new host can take on in a cluster.

These are all of the possible role values, which can be found in the `teleport` package.

```go
RoleAuth           Role = "Auth"
RoleWeb            Role = "Web"
RoleNode           Role = "Node"
RoleProxy          Role = "Proxy"
RoleAdmin          Role = "Admin"
RoleProvisionToken Role = "ProvisionToken"
RoleTrustedCluster Role = "Trusted_cluster"
RoleSignup         Role = "Signup"
RoleNop            Role = "Nop"
RoleRemoteProxy    Role = "RemoteProxy"
RoleKube           Role = "Kube"
RoleApp            Role = "App"
```

### Retrieve Token

The closest equivalent to this is `tctl tokens ls`.

```go
token, err := client.GetToken(tokenString)
if err != nil {
  return err
}
```

### Create Token

You can use the `GenerateToken` RPC to programmatically create a new token. This is the equivalent of `tctl tokens add --type=[Roles] --value=[Token] --ttl=[TTL]`.

By default, Teleport will create a random 16 byte string using the `CryptoRandomHex` function in our `utils` package. If you want to customize this yourself, simply provide the `Token` field, though we strongly recommend utilizing best security practices.

You can also set `TTL` to a maximum of 48 hours. The shorter the lifetime, the more secure your cluster will be.

```go
// generate a token for adding a new proxy host to a cluster
tokenString, err := client.GenerateToken(ctx, auth.GenerateTokenRequest{
  Roles: teleport.Roles{teleport.RoleProxy},
  // Token will be a randomly generated 16 byte hex string
  // TTL will default to 30 minutes
})
if err != nil {
  return err
}

// generate a token for adding a remote cluster to a trusted cluster
tokenString, err := client.GenerateToken(ctx, auth.GenerateTokenRequest{
  Token: "this-is-a-secure-token-string",
  Roles: teleport.Roles{teleport.RoleTrustedCluster},
  TTL:   time.Minute,
})
if err != nil {
  return err
}
```

### Update Token

`UpsertToken` is essentially the same as `GenerateToken` but without default values, so it is best used only for updating existing tokens.

```go
token, err := client.GetToken(tokenString)
if err != nil {
  return err
}

// update the token to be expired
token.SetExpiry(time.Now())
if err := client.UpsertToken(token); err != nil {
  return err
}
```

### Delete Token

This is equivalent to `tctl tokens rm [tokenString]`.

```go
if err := client.DeleteToken(tokenString); err != nil {
  return err
}
```

## Cluster Labels

Cluster Labels can be used to differentiate between leaf clusters in a [Trusted Cluster](trustedclusters.md). These can be useful when defining [roles](enterprise/ssh-rbac.md) within a trusted cluster, where each cluster has its own requirements for access.

For example, if each cluster corresponds to a different product that should only be accessed by its product team, you can give each cluster a label like `product: A`. Then create a role for each product which allows access to clusters with its respective product label.

You may want to use the following RPCs to manage your cluster labels if:

- You want to programmatically manage cluster labels from your root cluster
- You have a complex cluster labeling system that would benefit from automation with the API
- You have a large distributed trusted cluster where explicit cluster based access control is crucial

### Create a Leaf Cluster Join Token with Labels

To create a leaf cluster with cluster labels, you can create a token with the desired labels, and use that token to add the leaf cluster. Check the [Tokens](api-reference.md#tokens) section of this page for more information on tokens.

```go
tokenString, err := client.GenerateToken(ctx, auth.GenerateTokenRequest{
  Roles: teleport.Roles{teleport.RoleTrustedCluster},
  // Leaf clusters added with this token will inherit these labels
  Labels: map[string]string{
    "env": "staging",
  },
})
```

This is the equivalent of `tctl tokens add --type=trusted_cluster --labels=env=staging`.

!!! note

    Currently, it is not straightforward to add new leaf clusters with the API, but it is possible with the `RegisterUsingToken` RPC. Until we properly document this, follow the trusted cluster [join token docs](trustedclusters.md#join-tokens) to create a leaf cluster with this token using `tctl`.

### Update a Leaf Cluster's labels

You can also update an existing leaf cluster's labels from the root cluster using the `UpdateRemoteCluster` RPC.

This is the equivalent of `tctl update rc/[leafClusterName] --set-labels=env=prod`.

```go
rc, err := client.GetRemoteCluster("leafClusterName")
if err != nil {
  return err
}

md := rc.GetMetadata()
md.Labels = map[string]string{"env": "prod"}
rc.SetMetadata(md)

if err = client.UpdateRemoteCluster(ctx, rc); err != nil {
  return err
}

```

## Access Workflows

[Access Workflows](enterprise/workflow/index.md) can be used by Teleport users to request one or more additional roles on the fly. These requests can be partially or fully approved or denied by a Teleport Administrator.

You may want to use manage Access Workflows using the API if:

- You want to automatically administer the scaling up and down of permissions for developers depending on their task
- You want to utilize our supported [external tools](enterprise/workflow/index.md#integrating-with-an-external-tool) or other third party tools to control the flow of access

For example, you could have a team of contractors which need database access for some tasks, but should not have it permanently. To do this, you can give them the `contractor` role below, which allows them to request the `dba` role.

```yaml
kind: role
metadata:
  name: contractor
spec:
  options:
    # ...
  allow:
    request:
      roles: ['dba']
    # ...
  deny:
    # ...
```

```yaml
kind: role
metadata:
  name: dba
spec:
  options:
    # ...
    # Only allows the contractor to use this role for 1 hour from time of request.
    max_session_ttl: 1h
  allow:
    # ...
  deny:
    # ...
```

Now if a contractor has a task requiring `dba` access, they can request `dba` access. To approve the request, you need an administrator with read and write permissions to access requests.

```yaml
kind: role
metadata:
  name: request-admin
spec:
  options:
    # ...
  allow:
    rules:
    - resources: [access_request]
      verbs: [list, read, update, delete]
  deny:
    # ...
```

A `request-admin` can list all current requests, resolve them, and delete them. Notice that `request-admin` might not be a great job to handle manually.

With the API, you can automatically manage the requesting and or resolution of requests in order to streamline this process. Better yet, this opens up the ability to leverage external identity providers by attaching relevant information as `Annotations` to requests, such as `ticket_id` or `task_id`. You can also use our custom [integrations with external tools](enterprise/workflow/index.md#integrating-with-an-external-tool), such as Slack, to manage requests according to your custom configuration.

### The Access Request Object

An `AccessRequest` is made by a `User` for a set of `Roles`. Once its `State` is resolved to "approved", this user has access to the permissions in those roles until the `Expiry` time, which can be set upon resolution.

There are also optional `Reasons` and `Annotations` which can be used for audit logs, to integrate external identity information into requests, and other custom usages you may have.

```go
// AccessRequest represents an access request resource specification
type AccessRequestV3 struct {
  // Resource Fields are fields that all Teleport resources have - see above
  Resource Fields
  // Spec is an AccessRequest specification
  Spec AccessRequestSpecV3 struct {
    // User is the name of the user to whom the roles will be applied.
    User string
    // Roles is a list of the roles being requested.
    Roles []string
    // State is the current state of this access request. Possible values are pending, approved, and denied.
    State RequestState
    // Created encodes the time at which the request was registered with the auth server.
    Created time.Time
    // Expires constrains the maximum lifetime of any login session for which this request is active.
    Expires time.Time
    // RequestReason is an optional message explaining the reason for the request.
    RequestReason string
    // ResolveReason is an optional message explaining the reason for the resolution
    // of the request (approval, denial, etc...).
    ResolveReason string
    // ResolveAnnotations is a set of arbitrary values received from plugins or other resolving parties during approval/denial. Importantly, these annotations are included in the access_request.update event, allowing plugins to propagate arbitrary structured data to the audit log.
    ResolveAnnotations wrappers.Traits
    // SystemAnnotations is a set of programmatically generated annotations attached to pending access requests by teleport. These annotations serve as a mechanism for administrators to pass extra information to plugins when they process pending access requests.
    SystemAnnotations wrappers.Traits
  }
}
```

**State**

These are the RequestState constants, which can be found in the services package.

```go
// NONE variant exists to allow RequestState to be explicitly omitted
// in certain circumstances (e.g. in an AccessRequestFilter).
RequestState_NONE RequestState = 0
// PENDING variant is the default for newly created requests.
RequestState_PENDING RequestState = 1
// APPROVED variant indicates that a request has been accepted by
// an administrating party.
RequestState_APPROVED RequestState = 2
// DENIED variant indicates that a request has been rejected by
// an administrating party.
RequestState_DENIED RequestState = 3
```

### Retrieve Access Requests

The closest equivalent to this is `tctl request ls`, which does not have the filter functionality.

```go
// retrieve all pending access requests
filter := services.AccessRequestFilter{State: services.RequestState_PENDING}
ars, err := client.GetAccessRequests(ctx, filter)
if err != nil {
  return err
}
```

**AccessRequestFilter**

The `AccessRequestFilter` struct allows you to filter by `ID`, `User`, and `State`.

```go
type AccessRequestFilter struct {
  // ID specifies a request ID if set.
  ID string
  // User specifies a username if set.
  User string
  // RequestState filters for requests in a specific state.
  State RequestState
}
```

### Create Access Request

This is equivalent to `tctl request create contractor --roles=dba --reason="I need more power"`.

However with the RPC below, you can also set other useful fields. For example, `SystemAnnotations` can be used to store relevant information for external tools, such as a ticket id from a ticket management system.

```go
// create a new access request for contractor to temporarily use the dba role in the cluster
ar, err := services.NewAccessRequest("contractor", "dba")
if err != nil {
  return err
}

// use AccessRequest setters to set optional fields
accessReq.SetRequestReason("I need more power.")
accessReq.SetAccessExpiry(time.Now().Add(time.Hour))
accessReq.SetSystemAnnotations(map[string][]string{
  "ticket": []string{"137"},
})

if err = client.CreateAccessRequest(ctx, accessReq); err != nil {
  return err
}
```

### Approve Access Request

This is equivalent to `tctl request approve [accessReqID] --roles=dba1 --reason="dba2 is not for you"`.

You can approve a subset of the roles in the request with the `Roles` field.

```go
aruApprove := services.AccessRequestUpdate{
  RequestID: accessReqID,
  State:     services.RequestState_APPROVED,
  Reason:    "dba2 is not for you",
  Roles:     []string{"dba1"},
}
if err := client.SetAccessRequestState(ctx, aruApprove); err != nil {
  return err
}
```

### Deny Access Request

This is equivalent to `tctl request deny [accessReqID] --reason="Not today"`.

```go
aruDeny := services.AccessRequestUpdate{
  RequestID: accessReqID,
  State:     services.RequestState_DENIED,
  Reason:    "Not today",
}
if err := client.SetAccessRequestState(ctx, aruDeny); err != nil {
  return err
}
```

### Delete Access Request

This is equivalent to `tctl request rm [accessReqID]`.

```go
if err := client.DeleteAccessRequest(ctx, accessReqID); err != nil {
  return err
}
```

## Certificate Authority

Teleport uses SSH Certificates to securely connect servers. To achieve this, the Auth server of a Teleport cluster acts as the [Certificate Authority](architecture/authentication.md#ssh-certificates) (CA), which signs SSH certificates for users and hosts in the cluster. The auth server uses separate CAs for users and hosts.

You may want to use this API to manage your CA if:

- You need to access CA information from within the API for some use case
- You cannot [use tctl to rotate certificates](admin-guide.md#certificate-rotation) for some reason
- You want to set up a custom auto schedule for rotating certificates for more security and stability
- You want to implement a robust manual rotation solution, which automatically triggers each rotation phase according to your specification, such as by catching an event or webhook

### Certificate Rotation

To maintain security across your cluster, it is a good idea to set up automatic [certificate rotation](architecture/authentication.md#certificate-rotation).

You can use Teleport's `auto` rotation mode to rotate the CA with a default or custom schedule, or you can use `manual` mode to create a custom automated solution that manually triggers each phase.

A carefully implemented `manual` mode solution has the potential to be more fault tolerant and faster, due to the arbitrary nature of rotation schedules and grace periods (explained below).

**Rotation Phases**

A certificate rotation occurs in a series of phases, either triggered automatically or manually.

1. `Standby`: No rotation operations underway. This is the beginning and end state of every CA rotation. If a CA's rotation is not in the standby state, a new rotation cannot begin.
2. `Init`: New Certificate Authority is issued, but it remains unused while users and servers get updated certificates.
3. `Update Clients`: Client credentials will have to be updated and reloaded, but servers will still use and respond with old credentials (grace period).
4. `Update Servers`: Servers will have to reload and should start serving TLS and SSH certificates signed by new CA (retrieved in previous phase).
5. `Rollback`: Rollback moves back both clients and servers to use the old credentials, but will continue to trust new credentials as well. Must be triggered Manually.

The phases must occur in the order `Init -> Update Clients -> Update Servers` with the beginning and ending resting state being `Standby`. `Rollback` can occur after any phase.

**Automated Rotation**

You can use `tctl auth rotate --type=user --grace-period=10h` or the following RPC to start the rotation in `auto` mode.

```go
// This will start an automatic rotation that schedules each phase of the rotation in equal increments (each 1/3 of the grace period).
gracePeriod := time.Hour * 24
req := auth.RotateRequest{
  Mode: services.RotationModeAuto,
  GracePeriod: &gracePeriod, // defaults to 48 hours
  Type: services.UserCA, // Leave empty to target UserCA and HostCA
}
if err := client.RotateCertAuthority(req); err != nil {
  return err
}
```

The grace period should be set to 2-3 times the expected time to rotate the CA to ensure completion, while minimizing the grace period. The `type` flag is useful if you want to rotate both user and host CAs with different strategies or frequencies.

**Automated Rotation with a Custom Schedule**

You can also rotate certificates with a custom schedule. Using a custom certificate rotation schedule will allow you to target specific phase(s) and extend their length without having to use an unnecessarily long grace period, since long grace periods present a possible vulnerability.

```go
// This will automate your CA rotation with the custom schedule. Use with caution, each phase should have extra time to ensure they complete in less than optimal situations.
if err := client.RotateCertAuthority(auth.RotateRequest{
  Mode: services.RotationModeAuto,
  Schedule: &services.RotationSchedule{
    // 1 hour for Init
    UpdateClients: time.Now().UTC().Add(time.Hour),
    // 4 hours for UpdateClients
    UpdateServers: time.Now().UTC().Add(time.Hour * 5),
    // 2 hours for UpdateServers
    Standby: time.Now().UTC().Add(time.Hour * 7),
  },
}); err := client.RotateCertAuthority(req); err != nil {
  return err
}
```

**Manual Rotation** (custom automated solution)

You can set up a custom system for rotation by triggering each phase manually with `manual` mode. This can be done with `tctl auth rotate --phase=update_clients` or the following RPC.

```go
// You can run this RPC to start the Update Servers phase
if err := client.RotateCertAuthority(auth.RotateRequest{
  Mode:        services.RotationModeManual,
  TargetPhase: services.RotationPhaseUpdateServers,
}); err != nil {
  return err
}
```

This can be used to make rotations independent of an arbitrary rotation schedule or grace period. For example, you might be able to set up a custom automated solution where each phase is triggered by the event of the prior phase completing. This is possible in theory, though it may be complicated to set up.

However there are multiple upsides if you make it work:
- it would be quicker than `auto` mode since it wouldn't wait for a phase that is already complete
- it would be more error proof in cases where the servers miss their chance to update credentials, whether due to time constraints or from going offline during the rotation
- you would not need to worry about scaling the grace period with the size of your clusters
- you could catch rotation errors and automatically trigger the `Rollback` phase to try again (though this shouldn't be necessary outside of specific scenarios, such as servers going offline for long periods of time)

!!! note

    See our [TestRotateSuccess](https://github.com/gravitational/teleport/blob/645ac573c59240974a1306d28d79d1df3b2d9845/integration/integration_test.go#L3243) integration test to see how you might get started with implementing a manual rotation solution.

### Retrieve Certificate Authority

If you need to access specific information on your CA in a program, you can use the following RPC to retrieve the CA and view its keys, certificates, and more. This can also be done using `tctl auth export`.

```go
// retrieve the cluster's Certificate Authority for Hosts
ca, err := client.GetCertAuthority(
  services.CertAuthID{
    DomainName: clusterName,
    Type:       services.HostCA,
  },
  false,
)
if err != nil {
  return err
}

// use the CA getter methods to retrieve info about the CA
// For example, you can use GetTLSKeyPairs to get and decode the CA's certificates for use in your program
for _, k := range ca.GetTLSKeyPairs() {
  block, _ := pem.Decode(k.Cert)
  if block == nil {
    return fmt.Errorf("error decoding pem block")
  }
  cert, err := x509.ParseCertificate(block.Bytes)
  if err != nil {
    return err
  }

  // use cert
}
```
