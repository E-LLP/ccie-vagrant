# CCIE-Vagrant

Allows you to run CircleCI Enterprise Locally using VirtualBox, Vagrant, and Ngrok


# Getting Started

## Pre Reqs
Make sure you have [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads) installed.

## Configuration
1. Feel free to change `CIRCLE_CONTAINER_IMAGE_URI=` in `vagrant_init_builder.sh` to a bucket closer to you. We are pulling from US-West-2 by default.

## Installation
1. Clone this repo: `git clone git@github.com:circleci/ccie-vagrant.git`
2. `cd ccie-vagrant` and run `vagrant up`[1]
3. Go get a coffee, this will take a while
4. Once the Services Box finishes provisioning you will see the following output in the terminal:

    ```
    ==> services: ####################################################################################
    ==> services: ## Services box is getting ready.  Please follow the installation
    ==> services: ## wizard at the System Console at port 8800 (e.g. http://192.168.205.10:8800/ )
    ==> services: ##
    ==> services: ## When starting builder, use 192.168.205.10 as the SERVICES_PRIVATE_IP variable
    ==> services: ####################################################################################
    ```
5. Navigate to https://192.168.205.10:8800/ to continue the installation.
6. Select *Use Self-Signed Cert* on the first screen, then select *Continue without a hostname*
7. Select Choose license and grab the `support--internal.rli` license that is included in this repo.
8. Enter a password to secure the admin console (since we are using ngrok this will be accessible form the outside world, be sure to secure it!)
9. `ngrok` is included in this repo, set up a local tunnel so that GitHub can communicate with our local instance. `./ngrok http 192.168.205.10:80` if all goes well you should now see something like this in your terminal:

    ```
    ngrok by @inconshreveable                                                                                             (Ctrl+C to quit)

    Tunnel Status                 online
    Version                       2.0.25/2.0.25
    Region                        United States (us)
    Web Interface                 http://127.0.0.1:4040
    Forwarding                    http://ce5b357f.ngrok.io -> 192.168.205.10:80
    Forwarding                    https://ce5b357f.ngrok.io -> 192.168.205.10:80

    Connections                   ttl     opn     rt1     rt5     p50     p90
                                  0       0       0.00    0.00    0.00    0.00
    ```
10. Grab the $SUBDOMAIN.ngrok.io and add it to the hostname field.
11. Make a new GitHub App here https://github.com/settings/applications/new
    * Application Name can be Anything
    * Homepage URL should be the same as the from step 10
    * Authorization Callback URL should be Step 10 + /auth/github
    * Grab the ClientID and Client Secret
12. Select *Public GitHub* and enter the ClientID and Client Secret from the previous step
13. Uncheck SSL only
14. Select *None* for Storage
15. Skip Email Config
16. Select *I Agree*
17. Select *Save*
18. Select *Start Now*, you should now be redirected to the dashboard. Once the app finishes
pulling down all of the containers, you can go to your new instance via the dashboard.

## Usage

1. You can now log in to CCIE the same way as you normally would. Auth with GitHub, follow some projects, run some builds. Please note, the initial download[2] takes a bit of time. Depending on your internet speed you may be waiting around for a while.

## Caveats

1. If you need to go back to the replicated console, you cannot do so from within the app since ngrok is only forwarding the single port. You can get there manually by going to https://192.168.205.10:8800/dashboard.

## Vagrant Specific

We are using Vagrant [multi-machine](https://www.vagrantup.com/docs/multi-machine/) which allows us to spin up a little mini cluster like this. If you need to access the individual machines via SSH you just need to add their names.

`vagrant ssh services` or `vagrant ssh builder`
## Troubleshooting
[1] The most common cause of issues is port collisions. We are forwarding the following
ports on the services box:

```
services: 27017 => 27017 (adapter 1)
services: 8800 => 8800 (adapter 1)
services: 80 => 80 (adapter 1)
services: 443 => 443 (adapter 1)
services: 22 => 2222 (adapter 1)
```

Make sure none of these are in use locally.

[2] The initial download of the container image takes quite a bit of time. Once everything is ready you will see the containers available under fleet-state and you can start builds. Be patient, if you are bored you can check the status of the initial image download with `watch -n 1 ls -al /mnt/tmp`
