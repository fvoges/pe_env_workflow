# PE 3.7 Dynamic Environment Workflow

__This document is still under development (e.g. better wording)__

## Overview

This repository aims to propose a solution to a fluid workflow around
dynamic environment testing when using Puppet Enterprise 3.7's node classifier.

By design, we're affected by two realities:

* The node classifier has the ability to enforce an environment (default)
* The node classifier doesn't allow classifying with arbitrary classes

These are Good Things - we want the ability to lock down an agent's environment
and we want the console to verify that a class exists in a given environment
when attempting to classify a group with it.

However, we want to be able to test new codes on test machines (e.g. vagrant)
against temporary environments.  We also want to be able to create a new class
in that test environment and test an agent against it without having to login
to the console to do it, or using the API to create a group just for this
test - a test that will typically be very short-lived.

## Scenario

* A user wants to use 3.7's node manager for the features it provides, such
  as RBAC, REST API, and environment authority.
* The user wants node classification handled exclusively by the 3.7 node
  manager, including the environment pinning.
* The user wants test nodes to be able to specify an environment on the fly.
* The user wants the ability to test arbitrary classes (e.g. roles) without
  classifying a group with this in the node manager (via the browser or REST
  API) and without that class being present in mature, static environments.
* The user wants to create a feature branch from their control repository,
  providing a new Puppet environment to test an agent against.
* The user is creating a brand new 'role' or class in this feature branch that
  isn't present in other environments.

In Puppet Enterprise 3.7's node classifier, it's not exactly dynamic to do the
above.  To test new code in a test environment, the user would have to create a
new node group, match a node against that group, and classify that group with
the class(es) they want to test (e.g. the new role they're developing).

### What's undesirable

The requirement of classifying a node with the class you want to test has
always been present (duh).  Previously, it was not uncommon to use other means
of classification outside of the console, such as Hiera with `hiera_include()`,
logic in `site.pp` to evaluate a custom fact (e.g. `include $::role`), or
something else.  This afforded dynamic means of classification that didn't
involve clicking around or making API calls (with some caveats, of course).  PE
3.7's new node classification features make it a compelling tool to use - RBAC
and the REST API, for instance.

Doing this for quick test nodes that live very short lives creates more
friction and delay than desirable.  Users want to be able to quickly branch
from their control repository and test a new class in it with as little
effort as possible.  Creating a node group for this, adding the node to that
group, adding the test class to that group is a bit too involved for a test.

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

In this solution, we used a _component module_ on purpose.  This allows us to
have a drop-in module that's available in all environments.  Since we're
letting the node classifier manage the environment for non-test agents and have
only classified the test node group with this class, we don't risk production
agents from changing classification.  __Only the nodes that are a member of
the test group will be able to use this functionality.__

The component module also makes this easily removable in the future, should
workflow improvements be made.

Our simple class for including the top-scope variable is _available_ in all
environments, and that's fine.  Again, it's only used in the test group.

You'll at least need this class available in the __parent__ group of the
test group.  When you set the "agent-specified" group's classification, the
node classifier will search for the test class in the `modulepath` for that
environment.  If it's not there, you cannot classify that test group with it.

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

## Other Things

__Classifying test nodes using the API__

This was discussed.  We could leverage the new REST API to create a temporary
group during testing, classify that group with the class(es) we want to test,
and remove it when it's done.  However, that would require SSL certificates to
be used and resourced by something secure.  We certainly don't want our test
agents doing this - having keys to the classifier.  Other solutions seem more
complicated and maybe fragile for this use case.

__Create a 'dev' group that inherits production__

What this means is - we have a node group for "production."  Its environment
is locked and it's classified as desired.  To test new code for that group,
we could create a child group that inherits it and set the environment to
'agent-specified.'  This only solves one of the problems - being able to test
against test environments.  What about testing brand new code that the parent
environment isn't classified with?  We don't want to have to classify a group
with that test code just to test it.  Multiply this several times and you'd
see the implications it has on a fluid workflow.  This would commonly involve
either removing that temporary classification after our testing or
adding/removing groups to test.

__Don't use the node classifier__

The features of 3.7 are compelling and desirable by customers.  They want RBAC
and an API.  They want the environment-locking for non-test nodes.  However,
they still want to be able to easily test arbitrary things quickly without
a lot of overhead or complexities.

__Adopt a new workflow for the 3.7 classifier__

From our findings, a workflow that offers that dynamic isn't possible with 3.7
for the reasons mentioned above.  If it's difficult to test, testing is in
jeopordy of not being performed.

__What would a formal procedure look like in product__

Not sure.  Ideas?

__This is too hacky__

We're interested in other solutions that allow for easily testing new code in
test environments that don't sacrifice the new classifier features for non-test
agents.

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
