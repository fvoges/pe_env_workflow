# PE 3.7 Dynamic Environment Workflow

__This document is still under development (e.g. better wording)__

## Overview

This repository aims to propose a solution to a fluid workflow around two
conditions in Puppet Enterprise 3.7 node classifier:

* The node classifier has the ability to enforce an environment (default)
* The node classifier doesn't allow classifying with arbitrary classes

## Scenario

* A user wants to use 3.7's node manager for the features it provides, such
  as RBAC, REST API, and environment authority.
* The user wants node classification handled exclusively by the 3.7 node
  manager, including the environment pinning.
* The user wants test nodes to be able to specify an environment.
* The user wants the ability to test arbitrary classes (e.g. roles) without
  classifying a group with this in the node manager (via the browser or REST
  API).
* The user wants to create a feature branch from their control repository,
  providing a new Puppet environment to test an agent against.
* The user is creating a brand new 'role' or class in this feature branch that
  isn't present in other environments.

In Puppet Enterprise 3.7's node classifier, it's not exactly simple to do the
above.  The user would have to create a new node group, match a node against
that group, and classify that group with the class(es) they want to test (e.g.
the new role they're developing).

### What's undesirable

The requirement of classifying a node with the class you want to test has
always been present (duh).  Previously, it was not uncommon to use other means
of classification outside of the console, such as Hiera with `hiera_include()`,
logic in `site.pp` to evaluate a custom fact (e.g. `include $::role`), or
something else.  This afforded dynamic means of classification that didn't
involve clicking around or making API calls (with some caveats, of course).  PE
3.7's new node classification features make it a compelling tool to use - RBAC
and the REST API, for instance.

## Solution #1

1. Create a new group in the PE console that will remain present. Set the
   group to inherit the `default` group (or whatever) and set the environment
   to `agent-specified`
2. Create a component module or a profile class that evaluates a top-scope
   variable/fact and calls the `include()` function against its value. For
   example:
   ```puppet
   class env_testing {
     if $::testclass {
       include $::testclass
     }
   }
   ```

Nodes can be a member of the test group based on whatever logic is appropriate.
For example, maybe this group matches the value of `clientcert` against a
regex pattern such as _"vagrant"_.  Maybe a custom fact is made available on
test agents that this group matches against. Maybe `virtual == virtualbox` is
the criteria.

This affords users the ability to use the new environment-locking of non-test
agents while taking advantage of the `agent-specified` setting to allow
minimal-friction testing of test agents, such as short-lived vagrant instances
or cloud instances.

And a test run:

```shell
FACTER_testclass=role::something::new \
  puppet agent -t --environment=feature43
```

## Solution #2

`site.pp` can be utilized to offer similiar functionality as solution #1.
However, keep in mind that `site.pp` is global, so some precautions would need
to be taken to prevent non-test nodes from overriding their classification.

This method avoids needing to classify a group in the console at all. However,
a test node still needs to be a member of a group that allows for
agent-specified environments.

In `site.pp`, for example:

```puppet
$protected_environments = [
  'production',
  'staging',
  'dev',
]

unless member($protected_environments, $::environment) {
  if $::testclass {
    include $::testclass
  }
}
```

And a test run:

```shell
FACTER_testclass=role::something::new \
  puppet agent -t --environment=feature43
```

## Solution #3

See [https://docs.google.com/a/puppetlabs.com/drawings/d/1qTbdrtobn-PI97z1z9kQ3WWLnQD_pL4ovH_6qXt0mhQ/edit](https://docs.google.com/a/puppetlabs.com/drawings/d/1qTbdrtobn-PI97z1z9kQ3WWLnQD_pL4ovH_6qXt0mhQ/edit)

TODO: Some words about this here.

## References

TODO: Describe these links

* [https://tickets.puppetlabs.com/browse/PE-7236](https://tickets.puppetlabs.com/browse/PE-7236)
* [https://tickets.puppetlabs.com/browse/PE-7237](https://tickets.puppetlabs.com/browse/PE-7237)

* [https://docs.google.com/a/puppetlabs.com/document/d/1WIx2MZvyDXZnUNIpSqJgHSPbtgTlaXo2_IPpKSX6kJM/edit#heading=h.ddo08018ox5v](https://docs.google.com/a/puppetlabs.com/document/d/1WIx2MZvyDXZnUNIpSqJgHSPbtgTlaXo2_IPpKSX6kJM/edit#heading=h.ddo08018ox5v)

* [https://docs.google.com/a/puppetlabs.com/document/d/1caRuLnTy1WBdfgnuM36gB6VewpcJ3aa4auPQiB47aCo/edit#heading=h.ipok8cwppz55](https://docs.google.com/a/puppetlabs.com/document/d/1caRuLnTy1WBdfgnuM36gB6VewpcJ3aa4auPQiB47aCo/edit#heading=h.ipok8cwppz55)

* [https://docs.google.com/a/puppetlabs.com/document/d/1SHLSQzFdkBaowTX2WYJ7jTzqP1KzsP4nG74eism27bQ/edit#heading=h.qz22cjl5om1b](https://docs.google.com/a/puppetlabs.com/document/d/1SHLSQzFdkBaowTX2WYJ7jTzqP1KzsP4nG74eism27bQ/edit#heading=h.qz22cjl5om1b)

* [https://confluence.puppetlabs.com/pages/viewpage.action?title=Changes+For+PSEs+in+PE+3.7&spaceKey=PS](https://confluence.puppetlabs.com/pages/viewpage.action?title=Changes+For+PSEs+in+PE+3.7&spaceKey=PS)

* [https://docs.google.com/a/puppetlabs.com/drawings/d/1qTbdrtobn-PI97z1z9kQ3WWLnQD_pL4ovH_6qXt0mhQ/edit](https://docs.google.com/a/puppetlabs.com/drawings/d/1qTbdrtobn-PI97z1z9kQ3WWLnQD_pL4ovH_6qXt0mhQ/edit)

## People

Devised during the 2015 SSKO by Ranjit Viswakumar, Andrew Brader, Robert Maury,
and  Josh Beard
