<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        version="1.0">
  <xsl:output
          method="html" encoding="UTF-8" indent="no"/>
  <xsl:template match="/error">
    <h1 class="error">Dit document kan niet weergeven worden</h1>
  </xsl:template>

  <xsl:template match="/wetgeving">
    <xsl:apply-templates select="node()"/>
  </xsl:template>

  <!-- If we have no match, make a div and pass through-->
  <xsl:template match="*">
    <xsl:call-template name="makeDivSimple"/>
  </xsl:template>

  <xsl:template match="alias-titels">
    <!-- Do nothing. -->
  </xsl:template>

  <xsl:template match="intitule">
    <h1 id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </h1>
  </xsl:template>

  <xsl:template match="lijst">
    <ul id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </ul>
  </xsl:template>

  <xsl:template match="dagtekening|plaats|functie|naam|voornaam|achternaam|organisatie">
    <span id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </span>
  </xsl:template>

  <xsl:template match="label
                        |plaats
                        |datum
                        |nr
                        |li.nr">
    <span id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </span>
    <!-- Add a space because 'Artikel 2' sometimes renders as 'Artikel2' -->
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="nadruk">
    <em id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </em>
  </xsl:template>

  <xsl:template match="sup|sub">
    <xsl:element name="{local-name()}">
      <xsl:attribute name="id">
        <xsl:value-of select="@about"/>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xsl:element>
  </xsl:template>


  <xsl:template match="intref">
    <!-- TODO wat is intrefgroep?-->

    <!-- Process reference in server code -->
    <!--<a id="{@about}" href="{@href}" class="intref">-->
    <xsl:apply-templates select="node()"/>
    <!--</a>-->
  </xsl:template>

  <xsl:template match="extref">
    <!-- Process reference in server code -->
    <xsl:choose>
      <xsl:when test="@href">
        <a id="{@about}" href="{@href}" class="extref">
          <xsl:apply-templates select="node()"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="wetsluiting
                        |titel
                        |tussenkop
                        |redactie
                        |wij
                        |ondertekenaar
                        |ondertekening
                        |koning
                        |gegeven
                        |regeling-sluiting
                        |considerans.al
                        |titeldeel
                        |al
                        |bron">
    <xsl:call-template name="makeDivSimple"/>
  </xsl:template>

  <xsl:template match="illustratie">
    <xsl:variable name="url">
      <xsl:choose>
        <xsl:when test="@url">
          <xsl:value-of select="@url"/>
        </xsl:when>
        <xsl:when test="@id">
          <!-- Create url from id -->
          <xsl:value-of select="concat('http://wetten.overheid.nl/Illustration/',@id)"/>
        </xsl:when>
        <xsl:when test="@bin-id">
          <!-- Create url from id -->
          <xsl:value-of select="concat('http://wetten.overheid.nl/Illustration/',@bin-id)"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="width">
      <xsl:if test="@breedte">
        <xsl:value-of select="concat('width: ', @breedte, ';')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:variable name="height">
      <xsl:if test="@hoogte">
        <xsl:value-of select="concat('height: ', @hoogte, ';')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:variable name="rotation">
      <xsl:if test="@rotatie">
        <xsl:value-of select="concat('transform: rotate(', @rotatie, 'deg);')"/>
      </xsl:if>
    </xsl:variable>
    <!-- TODO if either rotatie or schaal, create transform -->

    <xsl:variable name="float">
      <xsl:choose>
        <xsl:when test="@uitlijning = 'start'">
          <xsl:text>float: left;</xsl:text>
        </xsl:when>
        <xsl:when test="@uitlijning = 'end'">
          <xsl:text>float: right;</xsl:text>
        </xsl:when>
        <xsl:when test="@uitlijning = 'center'">
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <img
            data-type="{@type}"
            data-kleur="{@kleur}"
            style="{concat(@width,@height,@rotation,@scale,@float)}"
            alt="{@naam}"
            data-id="{@id}"
            src="{$url}"/>
  </xsl:template>

  <xsl:template name="makeDivSimple">
    <div id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </div>
  </xsl:template>

  <xsl:template match="artikel">
    <div id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </div>
  </xsl:template>

  <!-- Example table: simple: BWBR0031156 -->
  <!-- Example table: more complex: BWBR0006064 -->
  <!--<table frame="none" tabstyle="stcrt1">-->
  <xsl:template match="table">
    <!-- HTML table starts at tgroup, so wrap this 'table' in a div -->

    <!-- TODO does this still work for metalex? -->
    <div id="{@about}">
      <xsl:attribute name="class">
        <xsl:if test="@frame">
          <!--(top | bottom | topbot |all | sides | none)-->
          <xsl:value-of select="concat('frame-',@frame)"/>
        </xsl:if>
        <xsl:if test="@tabstyle">
          <xsl:value-of select="@tabstyle"/>
        </xsl:if>
        <xsl:if test="@orient">
          <!--(port | land)-->
          <xsl:value-of select="concat('orient-',@orient)"/>
        </xsl:if>
        <xsl:if test="number(@pgwide) &gt; 0">
          pgwide
        </xsl:if>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </div>
  </xsl:template>


  <xsl:template match="title|tussenkop">
    <h3 id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </h3>
  </xsl:template>

  <!--<tgroup align="left" char="" charoff="50" cols="3" colsep="0" rowsep="0">-->
  <xsl:template match="tgroup">
    <table id="{@about}">
      <xsl:attribute name="class">
        <xsl:call-template name="testColsep"/>
        <xsl:call-template name="testRowsep"/>
        <xsl:call-template name="testTgroupstyle"/>
      </xsl:attribute>
      <!-- <colspec colname="Col2" colwidth="1.62*"/>-->
      <!-- TODO colwidth, compute max, then make percentage out of ratio-->
      <colgroup>
        <xsl:for-each select="colspec">
          <col>
            <xsl:apply-templates select="colspec/node()"/>
            <xsl:attribute name="class">
              <xsl:if test="@colname">
                <xsl:value-of select="concat('col-',@colname)"/>
              </xsl:if>
              <xsl:call-template name="testColsep"/>
              <xsl:call-template name="testRowsep"/>
              <xsl:call-template name="testTgroupstyle"/>
              <!-- TODO transfer non-working colgroup CSS to table / td, with colname and style:{} presumably -->
              <xsl:call-template name="testRowsep"/>
              <xsl:if test="align">
                <!--(left|right|center|justify|char)-->
                <xsl:value-of select="concat('align-',@align)"/>
              </xsl:if>
            </xsl:attribute>
          </col>
        </xsl:for-each>
      </colgroup>
      <!-- @cols is required, containing the number of columns, but we can't do anything with that-->
      <!-- @char specifies the alignment character when the Align attribute is set to Char, can't do anything with that -->
      <!-- @charoff specifies the percentage of the column's total width that should appear to the left of the first occurance of the character identified in Char when the Align attribute is set to Char.-->
      <!-- Apply templated to the rest -->
      <xsl:for-each select="node()">
        <xsl:if test="not(colspec)">
          <xsl:apply-templates/>
        </xsl:if>
      </xsl:for-each>
    </table>
  </xsl:template>

  <xsl:template name="testTgroupstyle">
    <xsl:if test="tgroupstyle">
      <xsl:value-of select="concat('style-',@tgroupstyle)"/>
    </xsl:if>
  </xsl:template>
  <!-- <thead valign="bottom"> -->
  <xsl:template match="colspec">
    <!-- Already handled in tgroup-->
  </xsl:template>
  <xsl:template match="thead">
    <thead>
      <xsl:attribute name="class">
        <xsl:if test="@valign">
          <xsl:value-of select="concat('valign-',@valign)"/>
        </xsl:if>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </thead>
  </xsl:template>

  <xsl:template match="thead//entry">
    <th>
      <xsl:call-template name="setEntryAttributes"/>
      <xsl:apply-templates select="node()"/>
    </th>
  </xsl:template>


  <xsl:template match="tfoot">
    <tfoot>
      <xsl:attribute name="class">
        <xsl:call-template name="testAlign"/>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </tfoot>
  </xsl:template>


  <!-- Nested table -->
  <xsl:template match="entrytbl">
    <table id="{@about}">
      <!-- TODO <xsl:call-template name="setTableAttributes"/> -->
      <xsl:apply-templates select="node()"/>
    </table>
  </xsl:template>

  <xsl:template match="tbody">
    <tbody>
      <xsl:attribute name="class">
        <xsl:call-template name="testValign"/>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </tbody>
  </xsl:template>

  <xsl:template match="row">
    <tr id="{@about}">
      <xsl:call-template name="setRowAttributes"/>
      <xsl:apply-templates select="node()"/>
    </tr>
  </xsl:template>

  <xsl:template name="setRowAttributes">
    <xsl:attribute name="class">
      <xsl:call-template name="testRowsep"/>
      <xsl:call-template name="testValign"/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="tbody//entry">
    <td>
      <xsl:call-template name="setEntryAttributes"/>
      <xsl:apply-templates select="node()"/>
    </td>
  </xsl:template>

  <xsl:template match="lidnr">
    <span id="{@about}" class="{local-name()} h3">
      <xsl:apply-templates select="node()"/>
    </span>
  </xsl:template>

  <xsl:template match="li">
    <li id="{@about}" class="{local-name()}">
      <xsl:apply-templates select="node()"/>
    </li>
  </xsl:template>

  <xsl:template match="lid">
    <xsl:variable name="element">
      <!-- TODO is this correct? -->
      <xsl:value-of select="'lid'"/>
    </xsl:variable>

    <div id="{@about}" class="lid annotatable">
      <xsl:call-template name="makeAnnotatable">
        <xsl:with-param name="id" select="@about"/>
        <xsl:with-param name="nr"/>
        <xsl:with-param name="element" select="$element"/>
      </xsl:call-template>

      <xsl:apply-templates select="node()"/>
    </div>
  </xsl:template>

  <xsl:template match="kop">
    <xsl:variable name="nr">
      <xsl:value-of select=".//nr"/>
    </xsl:variable>
    <xsl:variable name="element">
      <xsl:value-of select="name(..)"/>
    </xsl:variable>
    <div class="kop annotatable" id="{@about}">
      <xsl:call-template name="makeAnnotatable">
        <xsl:with-param name="id" select="@about"/>
        <xsl:with-param name="nr" select="$nr"/>
        <xsl:with-param name="element" select="$element"/>
      </xsl:call-template>

      <xsl:apply-templates select="node()"/>
    </div>

  </xsl:template>

  <xsl:template name="testMoreRows">
    <xsl:if test="@morerows">
      <xsl:if test="number(@morerows) &gt; 0">
        <!--MoreRows indicates how many more rows, in addition to the current row, this Entry is to occupy. -->
        <xsl:attribute name="rowspan">
          <!--<xsl:message>Found <xsl:value-of select="@morerows"/> more rows.</xsl:message>-->
          <xsl:value-of select="1 + number(@morerows)"/>
        </xsl:attribute>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  <xsl:template name="testRowsep">
    <xsl:if test="number(@rowsep) &gt; 0">
      <xsl:text>rowsep</xsl:text>
    </xsl:if>
  </xsl:template>
  <xsl:template name="testColsep">
    <xsl:if test="number(@colsep) &gt; 0">
      <xsl:text>colsep</xsl:text>
    </xsl:if>
  </xsl:template>
  <xsl:template name="setEntryAttributes">
    <xsl:attribute name="class">
      <!-- TODO CSS doesn't respect all colgroup CSS styles (like align) -->
      <xsl:call-template name="testColname"/>
      <xsl:call-template name="testColsep"/>
      <xsl:call-template name="testRowsep"/>
      <xsl:call-template name="testValign"/>
      <xsl:call-template name="testAlign"/>
    </xsl:attribute>
    <xsl:call-template name="testMoreRows"/>
    <xsl:call-template name="testNameStartEnd"/>
    <xsl:call-template name="testSpanname"/>
    <xsl:call-template name="testTgroupstyle"/>
  </xsl:template>

  <xsl:template name="testSpanname">
    <xsl:if test="@spanname">
      <!-- SpanName is the name (defined in a SpanSpec) of a span. This cell will be rendered with the specified horizontal span.-->
      <!-- ??? -->
    </xsl:if>
  </xsl:template>

  <xsl:template name="testNameStartEnd">
    <xsl:if test="@nameend">
      <!-- NameEnd is the name (defined in a ColSpec) of the rightmost column of a span. On Entry, specifying both NameSt and NameEnd defines a horizontal span for the current Entry. (See also SpanName.)-->
      <!-- This would create a colspan in conjunction with colspec's data. Ignore it because it's too tricky to work out.-->
    </xsl:if>
    <xsl:if test="@namest">
      <!-- same for nameend-->
    </xsl:if>
  </xsl:template>

  <xsl:template name="testColname">
    <xsl:if test="@colname">
      <xsl:value-of select="concat('col-',@colname)"/>
    </xsl:if>
  </xsl:template>

  <xsl:template name="testValign">
    <xsl:if test="@valign">
      <xsl:value-of select="concat('valign-',@valign)"/>
    </xsl:if>
  </xsl:template>

  <xsl:template name="testAlign">
    <xsl:if test="@align">
      <!--(left|right|center|justify|char)-->
      <xsl:value-of select="concat('align-',@align)"/>
    </xsl:if>
  </xsl:template>

  <xsl:template name="makeAnnotatable">
    <xsl:param name="element"/>
    <xsl:param name="id"/>
    <xsl:param name="nr"/>
  </xsl:template>

</xsl:stylesheet>
