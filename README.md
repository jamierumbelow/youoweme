# You Owe Me!
### A simple way to harrass your friends and family until they pay you

You Owe Me! is a simple Sinatra app and hosted service that allows you to send IOU notifications to friends and family. Your authenticate with Stripe Connect and fill out a basic form; the ower gets an email alerting them and a really simple interface to pay it.

## Installation

You'll need to set up a new application inside Stripe's **Account Settings** .Get the source code, and install the gems:

	$ bundle install

You can now begin the server with `rackup`. There are a couple of environment variables required to configure it:

<table>
	<tr>
		<td>STRIPE_SECRET</td>
		<td>Your <strong>API Keys -> Secret Key</strong></td>
	</tr>

	<tr>
		<td>STRIPE_KEY</td>
		<td>Your <em>application's</em> <strong>CLIENT_ID</strong></td>
	</tr>

	<tr>
		<td>DATABASE_URL</td>
		<td>A DNS connection string to your database (passed into DataMapper)</td>
	</tr>
</table>

These environment variables can be set inside **~/.profile** files or straight from the command line. We can set these vars and run the `rackup` command easily:

	$ STRIPE_KEY=key STRIPE_SECRET=secret DATABASE_URL=mysql://localhost/test_database rackup

...and then open up your browser at `http://localhost:9292` and away you go.