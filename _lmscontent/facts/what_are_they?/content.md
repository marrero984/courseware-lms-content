Puppet automatically creates a set of variables for you called `facts`. <a href="https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html">Facts</a> contain useful information integral to a node, such as its operating system, its hostname, or its IP address. Use this information to create conditional logic: make code behave a certain way based on a set of conditions. To see a list of all the facts available, type the command `facter -p` on any system with Puppet installed.

## Task:

Type the command `facter -p` to get a list of all facts available.

<iframe src="https://magicbox.classroom.puppet.com/facts/what_are_they" width="100%" height="500px" frameborder="0"></iframe>

Most facts contain a single value like `"hostname": "host.puppet.com"` or `"kernel": "Linux"`. One way to use these facts is to create server-specific attribute values, perhaps as part of a string written to a file.

Example:

<pre>
file { '/etc/motd':
  content =&gt; "My hostname: ${hostname}",
}
</pre>

In this example, any system using this code will have its own hostname written into the file. In this way, you can have server-specific outcomes with a single piece of code. This means you don't have to rewrite your code for every single machine you're managing.

## Task:

Update the code below with the `$osfamily` fact so it is written into the `/etc/motd` file.

<iframe src="https://magicbox.classroom.puppet.com/facts/working_with_facts" width="100%" height="500px" frameborder="0"></iframe>
