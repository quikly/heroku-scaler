heroku-scaler
=============

Open up the schedulers setting page:

    $ heroku addons:open scheduler:standard

Set up jobs for when your want to scale your app.

For example if you create a job with the task:

    ruby scaler.rb -a quikly-prod -p web -q 3 -c 15 -s PX

... and set the next run to 5:00 UTC. The number of web dynos for the app "my-app" will be scaled to 3 at 5:00 in the morning UTC.


5:00 UTC / Midnight EST: ruby scaler.rb -a quikly-prod -p web -q 1 -s 1X
7:00 UTC / 2AM EST:      ruby scaler.rb -a quikly-prod -p web -q 1 -s PX
13:00 UTC / 8AM EST:     ruby scaler.rb -a quikly-prod -p web -q 2 -s PX



