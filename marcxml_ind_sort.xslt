<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:marc="http://www.loc.gov/MARC21/slim"
    exclude-result-prefixes="xs"
    version="2.0">

<xsl:template match="*">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
</xsl:template>

<xsl:template match="marc:datafield">
    <marc:datafield>
       <xsl:attribute name="tag" select="./@tag"/>
       <xsl:attribute name="ind1" select="./@ind1"/>
       <xsl:attribute name="ind2" select="./@ind2"/> 
       <xsl:apply-templates/>
    </marc:datafield>
</xsl:template>
    
</xsl:stylesheet>
