<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        version="1.0">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

  <xsl:template match="/">
    <inhoudsopgave>
      <xsl:apply-templates select="*"/>
    </inhoudsopgave>
  </xsl:template>

  <xsl:template match="*[./kop]">
    <xsl:variable name="id">
      <xsl:value-of select="@about"/>
    </xsl:variable>

    <xsl:element name="{local-name()}">
      <!-- Select attributes from element -->
      <xsl:attribute name="id">
        <xsl:value-of select="$id"/>
      </xsl:attribute>
      <xsl:attribute name="kop">
        <xsl:value-of select="./kop/@about"/>
      </xsl:attribute>
      <xsl:variable name="titel">
        <xsl:value-of select="kop/titel"/>
      </xsl:variable>
      <xsl:variable name="subtitel">
        <xsl:value-of select="kop/subtitel"/>
      </xsl:variable>
      <xsl:variable name="label_nr">
        <xsl:value-of
                select="concat((kop/nr|kop/label)[1], ' ', (kop/nr|kop/label)[2])"/>
      </xsl:variable>

      <!-- Normalize values and add as attributes -->
      <xsl:attribute name="label">
        <xsl:value-of select="normalize-space($label_nr)"/>
      </xsl:attribute>
      <xsl:if test="string-length($titel) &gt; 0">
        <xsl:attribute name="titel">
          <xsl:value-of select="normalize-space($titel)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length($subtitel) &gt; 0">
        <xsl:attribute name="subtitel">
          <xsl:value-of select="normalize-space($subtitel)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>
  <xsl:template match="*">
    <xsl:apply-templates select="*"/>
  </xsl:template>
  <!-- Remove text -->
  <xsl:template match="text()">
  </xsl:template>
</xsl:stylesheet>
