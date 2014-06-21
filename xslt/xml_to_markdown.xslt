<?xml version="1.0" encoding="UTF-8"?>
<?altova_samplexml file:///C:/Users/Maarten/Desktop/test.xml?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:xslt="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text" encoding="UTF-8"/>
	<xsl:template match="/error">
  </xsl:template>
	<xsl:template match="/wetgeving">
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<!-- Don't render metadata -->
	<xsl:template match="meta-data|historische-brondata"/>
	<!-- Pass through if we don't know what to do-->
	<xsl:template match="*">
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<xsl:template mode="dont-break-line" match="*">
		<xsl:apply-templates mode="dont-break-line" select="node()"/>
		<xsl:text> </xsl:text>
	</xsl:template>
	<xsl:template match="text()">
		<xsl:if test="string-length(.) > 0">
			<xsl:variable name="normalized">
				<xsl:value-of select="normalize-space(.)"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="string-length($normalized) = 0">
					<!-- String is only whitespace -->
					<xslt:text> </xslt:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="leading-whitespaces">
						<xsl:value-of select="substring-before(.,substring($normalized,1,1))"/>
					</xsl:variable>
					<xsl:if test="string-length($leading-whitespaces) > 0">
						<!-- Number of leading whitespaces bigger than 0 -->
						<xslt:text> </xslt:text>
					</xsl:if>
					<xsl:value-of select="normalize-space(.)"/>
					<!--Squash whitespace within text -->
					<!-- If string has trailing whitespace, also add a space at the end -->
					<!-- whitespaces: ' \f\n\r\t\v'
               But I only know how to make ' ', '\t' and '\n'. I guess it's all we need
          -->
					<xsl:choose>
						<xsl:when test="substring(., string-length(.)) = '	'">
							<!--tab-->
							<xsl:text> </xsl:text>
						</xsl:when>
						<xsl:when test="substring(., string-length(.)) = '&#10;' or substring(., string-length(.)) = '&#x9;' or substring(., string-length(.)) = '&#xD;' or substring(., string-length(.)) = '&#xA;'">
							<!-- carriage return -->
							<xsl:text> </xsl:text>
						</xsl:when>
						<xsl:when test="substring(., string-length(.)) = ' '">
							<!-- space -->
							<xsl:text> </xsl:text>
						</xsl:when>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
	<xsl:template mode="dont-break-line" match="text()">
		<xsl:if test="string-length(.) > 0">
			<xsl:variable name="normalized">
				<xsl:value-of select="normalize-space(.)"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="string-length($normalized) = 0">
					<!-- String is only whitespace -->
					<xslt:text> </xslt:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="leading-whitespaces">
						<xsl:value-of select="substring-before(.,substring($normalized,1,1))"/>
					</xsl:variable>
					<xsl:if test="string-length($leading-whitespaces) > 0">
						<!-- Number of leading whitespaces bigger than 0 -->
						<xslt:text> </xslt:text>
					</xsl:if>
					<xsl:value-of select="normalize-space(.)"/>
					<!--Squash whitespace-->
					<!-- If string has trailing whitespace, also add a space at the end -->
					<!-- whitespaces: ' \f\n\r\t\v'
             But I only know how to make ' ', '\t' and '\n'. I guess it's all we need
        -->
					<xsl:choose>
						<xsl:when test="substring(., string-length(.)) = '	'">
							<!--tab-->
							<xsl:text> </xsl:text>
						</xsl:when>
						<xsl:when test="substring(., string-length(.)) = '&#10;' or substring(., string-length(.)) = '&#x9;' or substring(., string-length(.)) = '&#xD;' or substring(., string-length(.)) = '&#xA;'">
							<!-- carriage return -->
							<xsl:text> </xsl:text>
						</xsl:when>
						<xsl:when test="substring(., string-length(.)) = ' '">
							<!-- space -->
							<xsl:text> </xsl:text>
						</xsl:when>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
	<!-- Start and end with a whitespace -->
	<xsl:template match="wetsluiting
                        |wij
                        |considerans.al
                        |titeldeel
                        |artikel
                        |verdragtekst
                        |divisie
                        |bijlage
                        |bron">
		<xsl:text>
</xsl:text>
		<xsl:apply-templates select="node()"/>
		<xsl:text>
</xsl:text>
	</xsl:template>
	<!-- End with a newline -->
	<xsl:template match="lid">
		<xsl:apply-templates select="node()"/>
		<xsl:text>
</xsl:text>
	</xsl:template>
	<!-- Start with a newline -->
	<xsl:template match="dagtekening|koning|plaats|datum|functie|naam|li">
		<xsl:text>
</xsl:text>
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<!-- Start with a double newline -->
	<xsl:template match="lijst">
		<xsl:text>

</xsl:text>
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<!-- Do nothing -->
	<xsl:template match="alias-titels"/>
	<xsl:template mode="dont-break-line" match="redactie">
		<xsl:text>
</xsl:text>
		<!-- Break line anyway, because we don't want this info in a header -->
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<!-- h2 with a vertical bar -->
	<!-- NOTE: We could add classes, e.g.
{.</xsl:text><xsl:value-of select="@class"/><xsl:text>}
But GitHub viewer doesn't support that
-->
	<xsl:template match="intitule">
		<xsl:text>
##</xsl:text>
		<xsl:apply-templates select="node()"/>
		<xsl:text>

</xsl:text>
	</xsl:template>
	<!-- h3 -->
	<xsl:template match="kop">
		<xsl:text>
###</xsl:text>
		<xsl:apply-templates mode="dont-break-line" select="node()"/>
		<xsl:text>

</xsl:text>
	</xsl:template>
	<!-- h4 -->
	<xsl:template match="tussenkop">
		<xsl:text>
###</xsl:text>
		<xsl:apply-templates mode="dont-break-line" select="node()"/>
		<xsl:text>

</xsl:text>
	</xsl:template>
	<xsl:template match="nr">
		<xsl:apply-templates mode="dont-break-line" select="node()"/>
		<xsl:text>

</xsl:text>
	</xsl:template>
	<xsl:template mode="dont-break-line" match="titel">
		<xsl:text>

####</xsl:text>
		<xsl:apply-templates mode="dont-break-line" select="node()"/>
		<xsl:text>

</xsl:text>
	</xsl:template>
	<!-- superscript <sup> -->
	<xsl:template match="sup|noot">&lt;sup&gt;<xsl:apply-templates select="node()"/>&lt;/sup&gt;</xsl:template>
	<xsl:template mode="dont-break-line" match="sup|noot">&lt;sup&gt;<xsl:apply-templates mode="dont-break-line" select="node()"/>&lt;/sup&gt;</xsl:template>
	<!-- subscript <sub> -->
	<xsl:template match="sub|inf">&lt;sub&gt;<xsl:apply-templates select="node()"/>&lt;/sub&gt;</xsl:template>
	<xsl:template mode="dont-break-line" match="sub|inf">&lt;sub&gt;<xsl:apply-templates mode="dont-break-line" select="node()"/>&lt;/sub&gt;</xsl:template>
	<!-- emphasis * -->
	<xsl:template match="nadruk">*<xsl:apply-templates select="node()"/>*</xsl:template>
	<xsl:template mode="dont-break-line" match="nadruk">*<xsl:apply-templates mode="dont-break-line" select="node()"/>*</xsl:template>
	<xsl:template match="ovl">&lt;span style="text-decoration-line:overline"&gt;<xsl:apply-templates select="node()"/>&lt;/span&gt;</xsl:template>
	<xsl:template match="ovl" mode="dont-break-line">&lt;span style="text-decoration-line:overline"&gt;<xsl:apply-templates select="node()" mode="dont-break-line"/>&lt;/span&gt;</xsl:template>
	<xsl:template match="unl">&lt;span style="text-decoration-line:underline"&gt;<xsl:apply-templates select="node()"/>&lt;/span&gt;</xsl:template>
	<xsl:template match="unl" mode="dont-break-line">&lt;span style="text-decoration-line:underline"&gt;<xsl:apply-templates select="node()" mode="dont-break-line"/>&lt;/span&gt;</xsl:template>
	<!-- reference [](http) -->
	<!-- TODO test -->
	<xsl:template match="extref">
		<xsl:if test="string-length(@ref) > 0">
			<xsl:text>[</xsl:text>
		</xsl:if>
		<xsl:apply-templates select="node()"/>
		<xsl:if test="string-length(@ref) > 0">
			<xsl:text>]</xsl:text>
			<xsl:text>(</xsl:text>
			<xsl:value-of select="@ref"/>
			<xsl:text>)</xsl:text>
		</xsl:if>
	</xsl:template>
	<xsl:template mode="dont-break-line" match="extref">
		<xsl:if test="string-length(@ref) > 0">
			<xsl:text>[</xsl:text>
		</xsl:if>
		<xsl:apply-templates mode="dont-break-line" select="node()"/>
		<xsl:if test="string-length(@ref) > 0">
			<xsl:text>]</xsl:text>
			<xsl:text>(</xsl:text>
			<xsl:value-of select="@ref"/>
			<xsl:text>)</xsl:text>
		</xsl:if>
	</xsl:template>
	<xsl:template match="illustratie">
		<xsl:text>![</xsl:text>
		<xsl:value-of select="@bin-id"/>
		<xsl:text>](</xsl:text>
		<xsl:value-of select="@url"/>
		<xsl:text>)
    </xsl:text>
	</xsl:template>
	<xsl:template mode="dont-break-line" match="illustratie">
		<xsl:text>![</xsl:text>
		<xsl:value-of select="@bin-id"/>
		<xsl:text>](</xsl:text>
		<xsl:value-of select="@url"/>
		<xsl:text>)
</xsl:text>
	</xsl:template>
	<xsl:template match="uitgifte|ondertekening">
		<xsl:text>

</xsl:text>
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<!-- ********** -->
	<!-- TABLES -->
	<!-- ********** -->
	<!-- Example table: simple: BWBR0031156 -->
	<!-- Example table: more complex: BWBR0006064 -->
	<!--<table frame="none" tabstyle="stcrt1">-->
	<xsl:template match="table">
		<!-- HTML table starts at tgroup, so ignore this 'table' -->
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<!--
Table starts here
-->
	<xsl:template match="tabeltitel">
		<xsl:text>*</xsl:text>
		<xsl:apply-templates mode="dont-break-line"/>
		<xsl:text>*</xsl:text>
	</xsl:template>
	<xsl:template match="tabeltitel" mode="dont-break-line">
		<xsl:text>*</xsl:text>
		<xsl:apply-templates/>
		<xsl:text>*</xsl:text>
	</xsl:template>
	<!--<tgroup
align="left"
char=""
charoff="50"
cols="3"
colsep="0"
rowsep="0">-->
	<xsl:template match="tgroup">
		<!--
TODO is this possible in markdown:

rowsep
If RowSep has the value 1 (true), then a rule will be drawn below all the rows in this TGroup (unless other, interior elements, suppress some or all of the rules). A value of 0 (false) suppresses the rule. The rule below the last row in the table is controlled by the Frame attribute of the enclosing Table or InformalTable and the RowSep of the last row is ignored. If unspecified, this attribute is inherited from enclosing elements.

-->
		<xsl:text>

</xsl:text>
		<xsl:call-template name="makeHeader"/>
		<xsl:call-template name="makeBody"/>
		<xsl:text>
</xsl:text>
	</xsl:template>
	<xsl:template match="colspec">
		<!-- Already handled in tgroup-->
	</xsl:template>
	<xsl:template match="thead">
		<thead>
			<xsl:attribute name="class">
      </xsl:attribute>
			<xsl:apply-templates select="node()"/>
		</thead>
	</xsl:template>
	<xsl:template name="makeHeader">
		<!-- Coming from tgroup -->
		<!-- Text alignment applying to the entire group -->
		<xsl:variable name="group-align">
			<xsl:choose>
				<!--(left|right|center|justify|char)-->
				<xsl:when test="normalize-space(@align) = 'center' or normalize-space(@align) = 'justify' ">
					<xsl:text>center</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="normalize-space(@align)"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="count(thead/row/entry) > 0">
				<!-- If we can find out the column names, use them -->
				<xsl:call-template name="makeHeaderNamed">
					<xsl:with-param name="group-align" select="$group-align"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<!-- Otherwise, use dashes as column names -->
				<xsl:call-template name="makeHeaderUnnamed">
					<xsl:with-param name="group-align" select="$group-align"/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="makeHeaderUnnamed">
		<xsl:param name="group-align"/>
		<!-- First row: column names -->
		<xsl:text>|</xsl:text>
		<xsl:for-each select=".//colspec">
			<xsl:text> --- |</xsl:text>
		</xsl:for-each>
		<xsl:text>
</xsl:text>
		<!-- Second row: column alignments -->
		<xsl:text>|</xsl:text>
		<xsl:for-each select=".//colspec">
			<xsl:if test="$group-align = 'left' or $group-align = 'center'">
				<!-- TODO check if overriden by column attribute -->
				<xsl:text>:</xsl:text>
			</xsl:if>
			<xsl:text>---</xsl:text>
			<xsl:if test="$group-align = 'right' or $group-align = 'center'">
				<!-- TODO check if overriden by column attribute -->
				<xsl:text>:</xsl:text>
			</xsl:if>
			<xsl:text>|</xsl:text>
		</xsl:for-each>
		<xsl:text>
</xsl:text>
	</xsl:template>
	<xsl:template name="makeHeaderNamed">
		<xsl:param name="group-align"/>
		<!-- First row: column names -->
		<xsl:text>|</xsl:text>
		<xsl:for-each select="thead/row/entry">
			<xsl:variable name="normalized">
				<xsl:value-of select="normalize-space(.)"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="string-length($normalized)>0">
					<!-- TODO apply templates: maybe there's emphasis, but watch out that there's no line breaks involved -->
					<xsl:apply-templates mode="dont-break-line" select="node()"/>
					<xsl:text>|</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<!-- Empty column name -->
					<xsl:text>--- |</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:for-each>
		<xsl:call-template name="makeSecondRowNamed">
			<xsl:with-param name="group-align" select="$group-align"/>
		</xsl:call-template>
	</xsl:template>
	<xsl:template name="makeSecondRowNamed">
		<xsl:param name="group-align"/>
		<!-- Second row: lines and alignment -->
		<xsl:text>
|</xsl:text>
		<xsl:for-each select="thead/row/entry">
			<xsl:if test="$group-align = 'left' or $group-align = 'center'">
				<!-- TODO check if overridden by column attribute -->
				<xsl:text>:</xsl:text>
			</xsl:if>
			<xsl:text>---</xsl:text>
			<xsl:if test="$group-align = 'right' or $group-align = 'center'">
				<!-- TODO check if overridden by column attribute -->
				<xsl:text>:</xsl:text>
			</xsl:if>
			<xsl:text>|</xsl:text>
		</xsl:for-each>
		<xsl:text>
</xsl:text>
	</xsl:template>
	<xsl:template name="makeBody">
		<!-- Coming from tgroup -->
		<xsl:for-each select="tbody/row">
			<xsl:text>|</xsl:text>
			<xsl:for-each select="entry">
				<!-- cell text -->
				<xsl:variable name="normalized">
					<xsl:value-of select="normalize-space(.)"/>
				</xsl:variable>
				<xsl:choose>
					<xsl:when test="string-length($normalized)>0">
						<xsl:apply-templates mode="dont-break-line" select="node()"/>
						<xsl:text>|</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<!-- Empty column name -->
						<xsl:text> --- |</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			<xsl:text>
</xsl:text>
		</xsl:for-each>
	</xsl:template>
	<xsl:template match="thead//entry">
		<th>
			<xsl:apply-templates select="node()"/>
		</th>
	</xsl:template>
	<xsl:template match="lidnr">
		<xsl:text>
</xsl:text>
		<xsl:apply-templates select="node()"/>. </xsl:template>
	<xsl:template match="li.nr">
		<xsl:choose>
			<xsl:when test="normalize-space(.) = '•'">
				<xsl:text>*</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="node()"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="li">
		<xsl:text>

</xsl:text>
		<xsl:apply-templates select="node()"/>
	</xsl:template>
	<xsl:template match="lid">
		<xsl:apply-templates select="node()"/>
	</xsl:template>
</xsl:stylesheet>
