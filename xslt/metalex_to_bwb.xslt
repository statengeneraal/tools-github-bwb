<?xml version="1.0" encoding="UTF-8"?>
<?altova_samplexml file:///C:/Users/Maarten/Desktop/traite.xml?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:ml="http://www.metalex.eu/metalex/1.0"
                exclude-result-prefixes="ml" version="2.0">
  <xsl:output method="xml" encoding="UTF-8"/>
  <xsl:template match="/error">
    <xsl:copy/>
  </xsl:template>
  <xsl:template match="/ml:root">
    <wetgeving>
      <xsl:apply-templates select="*"/>
    </wetgeving>
  </xsl:template>

  <!-- If we have no match, do nothing -->
  <xsl:template match="*">
  </xsl:template>

  <xsl:template match="*[@class]">
    <xsl:call-template name="addSpaceIfMidSentenceStart"/>
    <xsl:element name="{@class}">
      <xsl:attribute name="about">
        <xsl:value-of select="@about"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </xsl:element>
    <xsl:call-template name="addSpaceIfMidSentenceEnd"/>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>

  <!-- Add a space only if the next character is not a period, comma, colon, semicolon, exclamation mark of question mark -->
  <xsl:template name="addSpaceIfMidSentenceStart">
    <xsl:variable name="apos">
      <xsl:text>'</xsl:text>
    </xsl:variable>

    <xsl:variable name="this-string">
      <xsl:value-of select="normalize-space(.)"/>
    </xsl:variable>


    <xsl:variable name="last-char">
      <xsl:value-of select="substring($this-string, string-length($this-string))"/>
    </xsl:variable>
    <xsl:variable name="first-char">
      <xsl:value-of select="substring($this-string, 1, 1)"/>
    </xsl:variable>

    <xsl:variable name="previous-text">
      <xsl:value-of select="normalize-space(preceding-sibling::node()[self::text()|self::*][1])"/>
    </xsl:variable>

    <xsl:if test="string-length($previous-text) > 0 and string-length($this-string) > 0">

      <xsl:variable name="previous-char">
        <xsl:value-of select="substring($previous-text, string-length($previous-text), 1)"/>
      </xsl:variable>

      <xsl:if test="
    local-name(.) != 'sup'
    and local-name(.) != 'sub'
    and local-name(.) != 'inf'
    and $previous-char != '('
    and $previous-char != $apos
    and $previous-char != '&quot;'
    and $first-char != '.'
    and $first-char != ','
    and $first-char != ':'
    and $first-char != ';'
    and $first-char != '!'
    and $first-char != '?'
    and $first-char != ')'">
        <!-- Add space if there's no punctation following -->
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- Add a space only if the next character is not a punctuation mark -->
  <xsl:template name="addSpaceIfMidSentenceEnd">
    <xsl:variable name="this-string">
      <xsl:value-of select="normalize-space(.)"/>
    </xsl:variable>

    <xsl:variable name="apos">
      <xsl:text>'</xsl:text>
    </xsl:variable>
    <xsl:variable name="last-char">
      <xsl:value-of select="substring($this-string, string-length($this-string))"/>
    </xsl:variable>
    <xsl:variable name="following-text">
      <xsl:value-of select="normalize-space(following-sibling::node()[self::text()|self::*][1])"/>
    </xsl:variable>
    <!-- only add if next node is a text node: an element will use addSpaceIfMidSentenceStart -->
    <xsl:if test="node()[self::text()|self::*][1][self::text()]">
      <xsl:if test="string-length($following-text) > 0 and string-length($this-string) > 0 and $last-char != $apos and $last-char != '('">
        <xsl:variable name="following-char">
          <xsl:value-of select="substring($following-text, 1, 1)"/>
        </xsl:variable>

        <xsl:if test="$following-char != '.'
    and $following-char != ','   
    and $following-char != ':'
    and $following-char != ';'
    and $following-char != '!'
    and $following-char != '?'
    and $following-char != ')'">
          <!-- Add space if there's no punctation following -->
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
