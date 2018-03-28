<script defer="[]" src="//code.jquery.com/jquery-1.11.2.js"></script>

<script defer="[]" src="https://try.puppet.com/js/selfpaced.js"></script>

<div id="lesson">

<div id="instructions">

<h3 class="instruction-header">
<strong>
<i class="fa fa-graduation-cap"></i> Lesson
</strong>
</h3>

<div class="instruction-content">

<p>So far, most of our Hiera data files have been in a single directory.
Depending on the complexity of your data, this might be fine,
but chances are you&#8217;ll want to split things up.</p>

<p>For example, what if you have some configuration that only applies to
individual nodes? It isn&#8217;t best practice, but sometimes you need to have a
couple of unique snowflakes in your infrastructure.</p>

<p>To support per-node configuration in Hiera, it&#8217;s best to use the <code>certname</code>
trusted fact. By default this is the fully qualified domain name of the node 
when the certificate was generated and it&#8217;s the unique name that the master 
knows the node by.  It&#8217;s more secure than using the hostname fact since a 
compromised node could report a false hostname, but it can&#8217;t fake another 
node&#8217;s certificate.</p>

<p>In order to keep all those YAML files from cluttering up our <code>hieradata</code> folder,
we&#8217;ll put them in a subfolder called <code>nodes</code>. By default, your <code>hiera.yaml</code> should
come with this level of the hierarchy already:</p>

<pre>
---
:backends: "yaml"
:yaml:
:hierarchy:
- "nodes/%{::trusted.certname}"
- "%{app_tier}"
- "common"
</pre>

<p>Let&#8217;s go back to the message of the day example to try this one out. Imagine
you&#8217;ve got two developers, Jane and Bob. They each have a development server
for testing out their code.</p>

<p>Jane wants to see some useful information when she logs in, so
<code>nodes/jane.puppetlabs.vm.yaml</code> looks like this:</p>
<pre>
---
message: "Welcome to ${hostname}. ${osfamily} - ${memorysize}"
</pre>

<p>Bob is more territorial, so <code>nodes/bob.puppetlabs.vm.yaml</code> looks like this:</p>
<pre>
---
message: "This is Bob's development server. Don't touch anything, or else!"
</pre>

<p>This isn&#8217;t limited to a single directory, you can have multiple subdirectories.
You can even use have more complex levels of the hierarchy. For example, if you
have multiple datacenters each with a <code>dev</code> and <code>prod</code> app tier, you could use 
a custom fact of <code>datacenter</code> to have something like this:</p>
<pre>
---
:backends: "yaml"
:yaml:
:hierarchy:
- "nodes/%{::trusted.certname}"
- "%{datacenter}/%{app_tier}"
- "common"
</pre>

<p>To test <code>trusted.certname</code> you&#8217;ll need to use <code>puppet agent</code> and you&#8217;ll obviously
only be able to test your actual trusted certname. Remember, you can&#8217;t use
<code>trusted.certname</code> with <code>puppet apply</code> and you can&#8217;t change the <code>hiera.yaml</code> hierarchy
on the master from your node.</p>

<p>To give a more complex configuration a try, use something like <code>hostname</code>
instead of <code>trusted.certname</code> in your node&#8217;s hiera.yaml. Then you can use
the <code>hiera</code> command line tool, which lets use specify the values for various
facts by passing them as parameters.</p>

<p>For example, to find out the MOTD on the dev servers in the Portland 
datacenter, you would use this command:</p>
<pre>
hiera message app_tier=dev datacenter=portland environment=production
</pre>

<p><code>environment</code> is specified here because the <code>hiera</code> command line tool
doesn&#8217;t supply any default facts or other variables.</p>

</div>

<h3 class="instruction-header">
<strong>
<i class="fa fa-desktop"></i> Practice
</strong>
</h3>

<div class="instruction-content">
<p>First, run <code>puppet agent -t</code> to set up your node for this lesson.</p>

<p>We&#8217;ve set up a complex hierarchy in the production code environment on your
agent node, explore a bit, add some key/value pairs, and see if you can get a
sense of how Hiera behaves. What happens if you use a hostname that doesn&#8217;t
have a corresponding YAML file? How about an app tier that doesn&#8217;t exist?
What if you set up conflicting values?</p>

<p>If this is starting to seem overwhelming, don&#8217;t worry. Hierarchies of more than
a few levels are unusual in practice, so don&#8217;t add complexity if you don&#8217;t need
it. Even this example is probably more complex than most users will ever
need.</p>

<p>Play around with <code>hiera</code> until you feel comfortable. Your node will expire after
15 minutes, but you can start a new one and run <code>puppet agent -t</code> to get the
starter code again. Once you&#8217;re done, head back to <a href="https://learn.puppet.com">learn.puppet.com</a>
to try some other self-paced courses or download the Learning VM for more
hands-on exercises.</p>
</div>

</div>

<div id="terminal">
<iframe id="try" src="https://try.puppet.com/sandbox/?course=get_hiera4" name="terminal"></iframe>
</div>

</div>