<!DOCTYPE html>
<html lang="en">
<style type="text/css">
  body {
    background-color: #3FBA54;
  }

  hr {
    height: 1px;
    border: 0px;
    background: #ffffff;
  }
</style>
<head>
<title>mope.io</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable  =no" />
<meta name="description" content="Survive and climb the food chain in mopeio, the hit browser game!">
<meta name="keywords" content="mope, mope.io, mopeio,io games, .io, spaceships, browser game, html game, html5 game, agario, diepio, flash game, space, multiplayer">
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<meta name="google-site-verification" content="HjdDaF_uw12IxXRm3hOS03tqv9QW8Lj5b74mlJGsRz0" />
<meta property="og:image" content="http://mope.io/img/share_banner.jpg">
<meta property="og:image:type" content="image/jpg">
<meta property="og:image:width" content="1263">
<meta property="og:image:height" content="707">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="robots" content="index, follow">
<meta name="revisit-after" content="3 days">
<meta name="googlebot" content="all">
<meta name="twitter:card" content="summary_large_image">

<link rel="stylesheet" href="main.css?v=1.224" />
<link rel="shortcut icon" type="image/x-icon" href="favicon.ico" />
<script data-cfasync="false" type="text/javascript">
    //ONLY LOAD AD SCRIPTS IF NOT MOBILE APP
    function getQueryParams(qs) {
      qs = qs.split("+").join(" ");
      var params = {},
        tokens,
        re = /[?&]?([^=]+)=([^&]*)/g;
      while ((tokens = re.exec(qs))) {
        params[decodeURIComponent(tokens[1])] = decodeURIComponent(tokens[2]);
      }
      return params;
    }
    var $_GET = getQueryParams(document.location.search);

    //read link/ app flags
    var isMobileAppIOS = $_GET["mobileios"] > 0;
    var isMobileAppAndroid = $_GET["mobileAndroid"] > 0;
    var isMobileApp = isMobileAppIOS || isMobileAppAndroid;
    if (isMobileApp) {
      console.log("Mobile App detected! (" + (isMobileAppIOS ? "IOS" : "Android") + ")");
    }




    if (!isMobileApp) {



      if (location.href.indexOf("http") > -1) {

        //<!-- curse ads script 1) -->
        var script = document.createElement('script');
        var tstamp = new Date();
        script.id = 'factorem';
        script.src = '//cdm.cursecdn.com/js/mope/cdmfactorem_min.js?sec=home&misc=' + tstamp.getTime();
        script.async = false;
        script.type = 'text/javascript';
        document.head.appendChild(script);
      }

      //<!-- FREESTAR .io PLACE THIS SECTION INSIDE OF YOUR HEAD TAGS -->
      /*var freestar = freestar || {};
      freestar.hitTime = Date.now();
      freestar.queue = freestar.queue || [];
      freestar.config = freestar.config || {};
      freestar.debug = window.location.search.indexOf('fsdebug') === -1 ? false : true;

      // Tag IDs set here, must match Tags served in the Body for proper setup
      freestar.config.enabled_slots = [
        "mope_300x250_336x280_top",
        "mope_970x90_728x90_bottom"
      ];

      ! function(a, b) {
        var c = b.getElementsByTagName("script")[0],
          d = b.createElement("script"),
          e = "https://a.pub.network/mope-io";
        e += freestar.debug ? "/qa/pubfig.min.js" : "/pubfig.min.js", d.async = !0, d.src = e, c.parentNode.insertBefore(d, c)
      }(window, document);
      */


    } else {
      console.log("Mobile App, not loading browser ads scripts.");
    }
  </script>
<script src="adblockdet/ads.js"></script>

<script>
    var aiptag = aiptag || {};
		aiptag.cmd = aiptag.cmd || [];
		aiptag.cmd.player = aiptag.cmd.player || [];
		// Show GDPR consent tool
		aiptag.gdprShowConsentTool = true;
		// If you use your own GDPR consent tool please set aiptag.gdprConsent = false; if an EU user has declined or not yet accepted marketing cookies, for users outside the EU or for users that accepted the GDPR please use aiptag.gdprConsent = true;

		aiptag.cmd.player.push(function() {
			adplayer = new aipPlayer({
				AD_WIDTH: 960,
				AD_HEIGHT: 540,
				AD_FULLSCREEN: false,
				AD_CENTERPLAYER: false,
				LOADING_TEXT: 'loading advertisement',
				PREROLL_ELEM: function() {
					return document.getElementById('preroll')
				},
				AIP_COMPLETE: function() {
					/*******************
					 ***** WARNING *****
					 *******************
					 Please do not remove the PREROLL_ELEM
					 from the page, it will be hidden automaticly.
					 If you do want to remove it use the AIP_REMOVE callback.
					*/
          onVideoAdFinished(true);
					//alert("Ad Completed");
				},
				AIP_REMOVE: function() {
					// Here it's save to remove the PREROLL_ELEM from the page.
					// But it's not necessary.
				}
			});
		});
	</script>
<script async src="//api.adinplay.com/libs/aiptag/pub/MOP/mope.io/tag.min.js"></script>
</head>
<body>
<div id="gameAreaWrapper">

<input id="chatinput" type="text" class="chat-input" placeholder="Chat here..." maxlength="35" />
<canvas tabindex="1" id="gCanvas"></canvas>
</div>
<div id="connecting" style="height:170px;">
<div style="height:100px;width:100px;margin: 0 auto;">
<img class="conimg" src="skins/mouse.png" width="100px" />
</div>
<p>Connecting...</p>
<p id="txtServer" style="font-size:16px;">
</p>
</div>

<div id="preroll" class="vidAd"></div>

<div id="pvVidContainer" class="vidAd" style="width:640px;height:360px; display:none;">
</div>
<div>
<div id="my-content-2" style="display:none; visibility:hidden;">
</div>
</div>
<div id="startMenuWrapper">
<div id="updates">
<div id="updatesDiv">
<h2>Oct 25th</h2>
<ul>
<li>Mobile: you can now lift your finger up to stop moving.</li>
<li>We're working hard to finish the accounts/ shop update, coming pretty soon!</li>
</ul>
<h2>Aug 16</h2>
<ul>
<li>Fixed bugs and video ads.</li>
</ul>
<h2>July 8: Bug Fixes</h2>
<ul>
<li>Fixed issues with food/water not spawning properly around the game.</li>
<li>Fixed mouse and ducks walking on hills after getting hurt.</li>
</ul>
<h2>June 18: Bug Fixes</h2>
<ul>
<li>NERF: Trex shaking damage removed. Damage occurs on first grab and then on bleeding</li>
<li>NERF: Trex can't grab diving ocean animals</li>
<li>NERF: Trex can't grab diving animals if they are diving for more than 2s</li>
<li>NERF: Golden Eagle rarity increased by 33%</li>
<li>NERF: Komodo Dragon's sweat duration/seat amount reduced by 20%</li>
<li>NERF: Flytrap's bite damage reduced by 20%</li>
<li>BUFF: King Crab's speed outside ocean increased to 10%</li>
<li>BUFF: Ice Monster's crystal growth/speed increased</li>
<li>FIXED: Pelican water bomb not hiting victims</li>
<li>FIXED: Pelican self hit from own water bomb </li>
<li>FIXED: Black Widow web teleport catching animals when spider is too far or was stunned</li>
<li>FIXED: Komodo Dragon teleport grab bug</li>
<li>FIXED: Black Dragon not healing in 1v1 arena</li>
<li>FIXED: Toucans not getting hurt in Desert biome (only lava toucan is allowed to not hurt)</li>
<li>FIXED: Objects going underneath Trees</li>
<li>FIXED: Melons not getting watered</li>
<li>FIXED: Killable food pushing animals out of hiding holes</li>
<li>FIXED: Bot spawning</li>
<li>FIXED: anti-teaming 0xp-bite</li>
<li>FIXED: Aniamls getting hit by bees while diving</li>
<li>NEW: Inside Arena, opponents go semi transparent so they can see through each other when fighting</li>
</ul>
<br>
</div>
<div id="ytDiv">
<h2>
Tell us your ideas/bugs on reddit:<br />
<a href="https://www.reddit.com/r/mopeio/" target="_blank">REDDIT PAGE</a>
<br />
<a href="https://www.youtube.com/channel/UCNfK9bZk3Br2KDjXXdKuM1g/community?view_as=subscriber&ab_channel=MopeioOfficial" target="_blank">Youtube Community</a>
<h2>
Try upcoming updates on the beta:<br />
<a href="http://beta.mope.io" target="_blank">beta.mope.io</a>
</h2>
<a href="http://www.mope.io/updates.txt" target="_blank">CHANGELOG</a>-
<a href="https://goo.gl/3ViH9K" target="_blank">IO GAMES</a>
<a href="http://mope.io/privacy" target="_blank">Privacy</a>
<br />
<div id="ytButton" style="margin-top: 7px;">
<script src="https://apis.google.com/js/platform.js"></script>
<div class="g-ytsubscribe" data-channelid="UCNfK9bZk3Br2KDjXXdKuM1g" data-layout="default" data-theme="dark" data-count="default"></div>
</div>
</div>
</div>
<div id="startMenu">
<div id="mopeMenu">
<img id="logo" src="img/logo.png" width="350px" height="99px" />
<div id="onconnectDiv" style="visibility:visible;">
<br />


<div class="optionsBtn">
<button id="settingsButton" class="button" type="submit" style="background-color:transparent; border-color:transparent;">
<img src="img/settings.png" width=30 height=30 />
</button>
</div>
<div id="nickInputContainer" style="display: block;">
<input id="nickInput" autofocus placeholder="Your name" maxlength="15" style="width: 100%; height: 40px; line-height: 36px;">
</div>
<a>
<button id="startButton">Play</button>
</a>
<p id="spawnXpLabel">
</p>
<p id="serverResponse">
</p>
</div>
<div id="optionsDiv">
<button id="closeBut" type="submit" class="button" style="background-color:transparent; border-color:transparent;">
<img src="img/x.png" width=35 height=35 />
</button>
<h3>Region/Server:</h3>
<select id="regionSelect">
<option>
Finding Best Region...
</option>
</select>
<select id="serverSelect">
<option>
Finding Server...
</option>
</select>
<h3>Options:</h3>
<div id="optionsContainer">
</div>
<br />
<a>
<button id="btnSpectate" style="display:block">Spectate</button>
</a>
</div>

<div id="moneyRectWrap">
<div id="moneyRect">




<div id="cdm-zone-02"></div>
</div>
</div>
</div>
</div>
<div id="rightSide">
<div id="appsDiv">
<a id="appAdIOS" href="https://goo.gl/ofAUPJ" target="_blank">
<img src="./img/appAd_ios.png" width="132" height="82" alt="GET THE IOS APP!" />
</a>
<a id="appAdAndroid" href="https://goo.gl/i3xQWQ" target="_blank">
<img src="./img/appAd_and.png" width="132" height="52" alt="GET THE Android APP!" />
</a>
</div>
</div>
<div id="moneyRectBottomWrap">
<div id="moneyRectBottom">



<div align="center" id="mope_970x90_728x90_bottom">
<script data-cfasync="false" type="text/javascript">
            /*if (!isMobileApp) {

              freestar.queue.push(function() {
                googletag.display('mope_970x90_728x90_bottom');
              });

            }*/
          </script>
</div>

<div id='cdm-zone-01'></div>
</div>
</div>
</div>

<script>
    var script = document.createElement('script');
    script.id = 'mopejs';
    script.src = 'client.js?x=' + (+new Date());
    script.async = false;
    script.type = 'text/javascript';
    document.head.appendChild(script);

    if (location.href.indexOf("http") == -1) {

      var hideUpdates = false;
      if (hideUpdates) {
        var updatesDiv = document.getElementById("updatesDiv");
        if (updatesDiv)
          updatesDiv.style.display = "none";
      }
    }
    //document.write("<script src='client.js?x=" + (+new Date()) + "'></" + "script>");
  </script>

<div id='cdm-zone-end'></div>
</body>


</html>