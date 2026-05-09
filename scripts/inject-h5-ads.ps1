param(
	[string]$HtmlPath = "build/web/index.html",
	[string]$Client = $env:ADSENSE_H5_CLIENT,
	[string]$Channel = $env:ADSENSE_H5_CHANNEL,
	[string]$FrequencyHint = $env:ADSENSE_H5_FREQUENCY_HINT,
	[string]$TestMode = $env:ADSENSE_H5_TEST_MODE,
	[string]$AdmobInterstitialSlot = $env:ADSENSE_H5_ADMOB_INTERSTITIAL_SLOT,
	[string]$AdmobRewardedSlot = $env:ADSENSE_H5_ADMOB_REWARDED_SLOT,
	[string]$ChildDirected = $env:ADSENSE_H5_CHILD_DIRECTED,
	[string]$UnderAgeOfConsent = $env:ADSENSE_H5_UNDER_AGE_OF_CONSENT
)

$ErrorActionPreference = "Stop"
$Marker = "arcadecore-h5-ads"

function Test-Truthy([string]$Value) {
	if ([string]::IsNullOrWhiteSpace($Value)) {
		return $false
	}
	return @("1", "true", "yes", "on") -contains $Value.Trim().ToLowerInvariant()
}

function Add-Attribute([System.Collections.Generic.List[string]]$Attributes, [string]$Name, [string]$Value) {
	if ([string]::IsNullOrWhiteSpace($Value)) {
		return
	}
	$encoded = [System.Net.WebUtility]::HtmlEncode($Value.Trim())
	$Attributes.Add(" $Name=`"$encoded`"")
}

function ConvertTo-AdSenseClient([string]$Value) {
	if ([string]::IsNullOrWhiteSpace($Value)) {
		return ""
	}

	$clean = $Value.Trim()
	if ($clean.StartsWith("ca-pub-", [System.StringComparison]::OrdinalIgnoreCase)) {
		return "ca-pub-" + $clean.Substring(7)
	}
	if ($clean.StartsWith("pub-", [System.StringComparison]::OrdinalIgnoreCase)) {
		return "ca-" + $clean
	}
	return $clean
}

if ([string]::IsNullOrWhiteSpace($Client)) {
	Write-Host "ADSENSE_H5_CLIENT not set; skipping H5 ads injection."
	exit 0
}

$Client = ConvertTo-AdSenseClient $Client

if (-not (Test-Path $HtmlPath)) {
	throw "HTML file not found: $HtmlPath"
}

$html = [System.IO.File]::ReadAllText($HtmlPath)
if ($html.Contains($Marker) -or $html.Contains("arcadecoreH5Ads")) {
	Write-Host "H5 ads code already present; skipping duplicate injection."
	exit 0
}

$attrs = [System.Collections.Generic.List[string]]::new()
Add-Attribute $attrs "data-ad-client" $Client
Add-Attribute $attrs "data-ad-channel" $Channel
Add-Attribute $attrs "data-ad-frequency-hint" $FrequencyHint
Add-Attribute $attrs "data-admob-interstitial-slot" $AdmobInterstitialSlot
Add-Attribute $attrs "data-admob-rewarded-slot" $AdmobRewardedSlot
if (Test-Truthy $TestMode) {
	$attrs.Add(' data-adbreak-test="on"')
}
if (Test-Truthy $ChildDirected) {
	$attrs.Add(' data-tag-for-child-directed-treatment="1"')
}
if (Test-Truthy $UnderAgeOfConsent) {
	$attrs.Add(' data-tag-for-under-age-of-consent="1"')
}

$encodedClient = [System.Net.WebUtility]::UrlEncode($Client.Trim())
$attributeText = [string]::Join("", $attrs)
$snippet = @"
<!-- ${Marker}:start -->
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$encodedClient" crossorigin="anonymous"$attributeText></script>
<script>
window.adsbygoogle = window.adsbygoogle || [];
window.adBreak = window.adConfig = function(o) { window.adsbygoogle.push(o); };
window.arcadecoreH5Ads = window.arcadecoreH5Ads || (function() {
  function hasApi() {
    return typeof window.adBreak === "function" && typeof window.adConfig === "function";
  }
  function callSafe(fn) {
    if (typeof fn === "function") {
      fn();
    }
  }
  return {
    configure: function(soundOn) {
      if (!hasApi()) {
        return false;
      }
      window.adConfig({
        preloadAdBreaks: "auto",
        sound: soundOn ? "on" : "off"
      });
      return true;
    },
    showInterstitial: function(name, beforeAd, afterAd, done) {
      if (!hasApi()) {
        callSafe(done);
        return false;
      }
      window.adBreak({
        type: "next",
        name: name || "arcadecore_interstitial",
        beforeAd: function() { callSafe(beforeAd); },
        afterAd: function() { callSafe(afterAd); },
        adBreakDone: function() { callSafe(done); }
      });
      return true;
    },
    showRewarded: function(name, beforeAd, afterAd, dismissed, viewed, done) {
      if (!hasApi()) {
        callSafe(done);
        return false;
      }
      window.adBreak({
        type: "reward",
        name: name || "arcadecore_rewarded",
        beforeAd: function() { callSafe(beforeAd); },
        afterAd: function() { callSafe(afterAd); },
        beforeReward: function(showAdFn) { showAdFn(); },
        adDismissed: function() { callSafe(dismissed); },
        adViewed: function() { callSafe(viewed); },
        adBreakDone: function() { callSafe(done); }
      });
      return true;
    }
  };
}());
</script>
<!-- ${Marker}:end -->
"@

if ($html -notmatch "(?i)</head>") {
	throw "Could not find </head> in $HtmlPath"
}

$updated = [System.Text.RegularExpressions.Regex]::Replace($html, "(?i)</head>", "$snippet`r`n</head>", 1)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($HtmlPath, $updated, $utf8NoBom)
Write-Host "Injected AdSense H5 Games Ads code into $HtmlPath."
