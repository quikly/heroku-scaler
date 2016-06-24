heroku-scaler
=============

Open up the schedulers setting page:

    $ heroku addons:open scheduler:standard

Set up jobs for when your want to scale your app.

For example if you create a job with the task:

    ruby scaler.rb -a quikly-prod -p web -q 3 -c 15 -s Performance-L

... and set the next run to 5:00 UTC. The number of web dynos for the app "my-app" will be scaled to 3 at 5:00 in the morning UTC.

```
EST/EDT -> +4 -> UTC
1AM ET --> 5  UTC:   ruby scaler.rb -a quikly-prod -p web -q 1 -s Standard-1
8AM ET --> 12 UTC:   ruby scaler.rb -a quikly-prod -p web -q 2 -s Performance-L
```

Common scenarios:

    ruby scaler.rb -a quikly-prod -p web -q 2 -c 3 -s Standard-2X
    ruby scaler.rb -a quikly-prod -p web -q 2 -c 15 -s Performance-L



A note from Heroku:

    When you update config vars a new release is created. The new
    release causes an application restart. Because you have preboot
    enabled, what actually happens is that new dynos are created in an
    unroutable state, while the old ones are kept running. Four
    minutes later the new dynos are made routable and the old ones are
    terminated.

    Shortly after this happens, you perform a scale and resize
    operation. What's important here is the scale operation: because
    you're scaling from N -> 1 we're removing all the old dynos and
    leaving your app with one new dyno, which is unroutable, and so you
    start seeing H99s because the router has out-of-date routing
    information and can't find a dyno to handle requests.

    Potential workarounds:
    - Disable and then re-enable preboot before performing this
    reconfiguration and scaling task.
    - Sleep for >4 minutes after updating config vars.
