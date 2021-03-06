<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:include href="Menu.xsl"/>
<xsl:include href="Alarms.xsl"/>

<xsl:template match="/Spuren">
<html>
<head>
	<title>Pending/Failed Announcements</title>
	<meta http-equiv="refresh" content="10"/>
	<link rel="stylesheet" type="text/css" href="css/style.css"/>
	<script type="text/javascript" src="js/jquery-2.1.1.min.js"/>
	<script type="text/javascript" src="js/jquery.timeago.js"/>
	<script type="text/javascript" src="js/jquery.time.js"/>
</head>
<body>
	<span class="title"><a href="http://spurtracer.sf.net"><b>Spur</b>Tracer</a></span>

	<div class="content">
		<xsl:call-template name="Menu">
			<xsl:with-param name="active" select="'Announcements'"/>
		</xsl:call-template>

		<div class="info">
			<p>Each announcement does indicate an interface that was triggered by one
			component, while not yet being processed by the component implementing
			the interface.</p>
			<p> Overdue announcements will time out according to the 
			<a href="getSettings#timeouts">timeout settings</a>.</p>
		</div>

		<div class="systemMap">
		<div class="header">Recent Pending/Failed Interfaces</div>
		<table border="0" class="notifications">
			<tr>
				<th>Time</th>
				<th colspan="2">From</th>
				<th>To</th>
				<th>New Context</th>
				<th>Source Context</th>
				<th>Status</th>
				<th>Since</th>
			</tr>
			<xsl:for-each select="InterfaceAnnouncements/InterfaceAnnouncement[@status != 'finished']">
				<xsl:sort select="@time" order="descending" data-type="number"/>
				<xsl:call-template name="InterfaceAnnouncement"/>
			</xsl:for-each>
		</table>
		</div>

		<div class="systemMap">
		<div class="header">Recent Pending/Failed Components</div>
		<table border="0" class="notifications">
			<tr>
				<th>Time</th>
				<th>Host</th>
				<th>Component</th>
				<th>Context</th>
				<th>Status</th>
				<th>Since</th>
			</tr>
			<xsl:for-each select="ComponentAnnouncements/ComponentAnnouncement[@status != 'finished']">
				<xsl:sort select="@time" order="descending" data-type="number"/>
				<xsl:call-template name="ComponentAnnouncement"/>
			</xsl:for-each>
		</table>
		</div>

		<div class="systemMap legend">
			<div class="header">Legend</div>
			<table>
				<tr><td class='announced'>announced</td></tr>
				<tr><td class='timeout'>timeout</td></tr>
			</table>
		</div>


		<div class="clear"/>
	</div>

	<!-- Unconditionally set timeago handler as it might be reused in other displays -->
	<script type="text/javascript">
		jQuery(document).ready(function() {
		 	jQuery(".timeago").timeago();

			jQuery.timeago.settings.strings.suffixAgo = null;

			jQuery(".since").timeago();

			jQuery(".time").time();
		});
	</script>
</body>
</html>
</xsl:template>

<xsl:template name="InterfaceAnnouncement">
	<xsl:element name="tr">
		<xsl:attribute name="class">announcement
			<xsl:if test="@status = 'announced'">announced</xsl:if>
			<xsl:if test="@status = 'timeout'">timeout</xsl:if>
		</xsl:attribute>
		<td class="time" title="{@time}000"><xsl:value-of select="@time"/>000</td>
		<td><a href="/getDetails?host={@host}"><xsl:value-of select="@host"/></a></td>
		<td><a href="/getDetails?component={@component}"><xsl:value-of select="@component"/></a></td>
		<td><a href="/getDetails?component={@newcomponent}"><xsl:value-of select="@newcomponent"/></a></td>
		<td><a href="/getSpur?ctxt={@newctxt}"><xsl:value-of select="@newctxt"/></a></td>
		<td><a href="/getSpur?ctxt={@ctxt}"><xsl:value-of select="@ctxt"/></a></td>
		<td><xsl:value-of select="@status"/></td>
		<td class="since" title="{@time * 1000}"><xsl:value-of select="@time * 1000"/></td>
	</xsl:element>
</xsl:template>

<xsl:template name="ComponentAnnouncement">
	<xsl:element name="tr">
		<xsl:attribute name="class">announcement
			<xsl:if test="@status = 'announced'">announced</xsl:if>
			<xsl:if test="@status = 'timeout'">timeout</xsl:if>
		</xsl:attribute>
		<td class="time" title="{@time}000"><xsl:value-of select="@time"/>000</td>
		<td><a href="/getDetails?host={@host}"><xsl:value-of select="@host"/></a></td>
		<td><a href="/getDetails?component={@component}"><xsl:value-of select="@component"/></a></td>
		<td><a href="/getSpur?ctxt={@ctxt}"><xsl:value-of select="@ctxt"/></a></td>
		<td><xsl:value-of select="@status"/></td>
		<td class="since" title="{@time * 1000}"><xsl:value-of select="@time * 1000"/></td>
	</xsl:element>
</xsl:template>


</xsl:stylesheet>
