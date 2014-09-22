<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
  <xsl:output
          method="html" encoding="UTF-8" indent="no"/>
  <xsl:template match="/error">
  </xsl:template>

  <xsl:template match="/*[*//kop]">
    <!-- Only proceed if there actually is a 'kop' below -->
    <lawly-menu multi="multi" id="toc" data-element="{local-name()}">
      <xsl:apply-templates mode="entered" select="*"/>
    </lawly-menu>
  </xsl:template>

  <!-- match kop -->
  <xsl:template mode="entered" match="*">
    <xsl:choose>
      <xsl:when test="./kop">
        <!-- There's a kop: make menu element -->

        <!-- Store values in variables -->
        <xsl:variable name="titel">
          <xsl:value-of select="kop/titel"/>
        </xsl:variable>
        <xsl:variable name="subtitel">
          <xsl:value-of select="kop/subtitel"/>
        </xsl:variable>
        <xsl:variable name="label_nr">
          <xsl:value-of select="concat((kop/nr|kop/label)[1], ' ', (kop/nr|kop/label)[2])"/>
        </xsl:variable>
        <xsl:variable name="id">
          <xsl:value-of select="kop/@about"/>
        </xsl:variable>

        <xsl:choose>
          <xsl:when test=".//*/kop">
            <!-- Submenu if there is another kop nested somewhere -->
            <lawly-menu multi="multi" data-element="{local-name()}" href="{concat('#', $id)}">
              <div class="item-content">
                <div class="label">
                  <xsl:value-of select="normalize-space($label_nr)"/>
                </div>

                <xsl:if test="string-length($titel) &gt; 0">
                  <div class="title">
                    <xsl:value-of select="normalize-space($titel)"/>
                  </div>
                </xsl:if>

                <xsl:if test="string-length($subtitel) &gt; 0">
                  <div class="subtitle">
                    <xsl:value-of select="normalize-space($subtitel)"/>
                  </div>
                </xsl:if>
              </div>
              <xsl:apply-templates mode="entered" select="*"/>
            </lawly-menu>
          </xsl:when>
          <xsl:otherwise>
            <!-- Terminal item-->
            <lawly-item href="{concat('#', $id)}" data-element="{local-name()}">
              <a href="{concat('#', $id)}">
                <div class="title-container">
                  <div class="label">
                    <xsl:value-of select="normalize-space($label_nr)"/>
                  </div>

                  <xsl:if test="string-length($titel) &gt; 0">
                    <div class="title">
                      <xsl:value-of select="normalize-space($titel)"/>
                    </div>
                  </xsl:if>

                  <xsl:if test="string-length($subtitel) &gt; 0">
                    <div class="subtitle">
                      <xsl:value-of select="normalize-space($subtitel)"/>
                    </div>
                  </xsl:if>
                </div>
              </a>
            </lawly-item>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <!-- There's not immediate kop child: proceed to drill deeper-->
        <xsl:apply-templates mode="entered" select="*"/>
      </xsl:otherwise>
    </xsl:choose>


  </xsl:template>

  <!-- Remove text -->
  <xsl:template match="text()">
  </xsl:template>
  <xsl:template mode="entered" match="text()">
  </xsl:template>
</xsl:stylesheet>
