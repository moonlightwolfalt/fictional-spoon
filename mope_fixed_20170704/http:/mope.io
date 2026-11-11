<!DOCTYPE html>
<html lang="en">
<style type="text/css">body{background-color:#3FBA54}</style>
<head>
<title>mope.io</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
<meta name="description" content="Survive and climb the food chain in mopeio, the hit browser game!">
<meta name="keywords" content="mope, mope.io, mopeio,io games, .io, spaceships, browser game, html game, html5 game, agario, diepio, flash game, space, multiplayer">
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<meta name="google-site-verification" content="HjdDaF_uw12IxXRm3hOS03tqv9QW8Lj5b74mlJGsRz0"/>
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
 
<link rel="stylesheet" href="main.css"/>
<link rel="shortcut icon" type="image/x-icon" href="favicon.ico"/>
 
 
<script>
        var script = document.createElement('script');
        var tstamp = new Date();
        script.id = 'factorem';
        script.src = '//cdm.cursecdn.com/js/mope/cdmfactorem_min.js?sec=home&misc=' + tstamp.getTime();
        script.async = false;
        script.type = 'text/javascript';
        document.head.appendChild(script);
    </script>
</head>
<body>
<div id="gameAreaWrapper">
<input id="chatinput" type="text" class="chat-input" placeholder="Chat here..." maxlength="35"/>
<canvas tabindex="1" id="gCanvas"></canvas>
</div>
<div id="connecting">
<p id="desc">Connecting...</p>
<div class="spinner">
<div class="bounce1"></div>
<div class="bounce2"></div>
<div class="bounce3"></div>
</div>
</div>
 
<div id="preroll" class="vidAd"></div>
 
<div id="pvVidContainer" class="vidAd" style="width:640px;height:360px; display:none;">
</div>
<div>
<div id="my-content-2" style="display:none; visibility:hidden;">
</div>
</div>
 
<div id="startMenuWrapper">
<div id="startMenu">
<img id="logo" src="img/logo.png" width="350px" height="178px"/>
<div id="onconnectDiv" style="visibility:hidden;">
<button id="button_GMnormal" class="button" type="submit" style="">
<img src="img/mode_norm.png" width=124 height=48/>
</button>
<button id="button_GMsandbox" class="button" type="submit" style="">
<img src="img/mode_sandbox.png" width=124 height=48/>
</button>
<div id="nickInputContainer" style="display: block;">
<input id="nickInput" autofocus placeholder="Your name" maxlength="15" style="width: 100%; height: 40px; line-height: 36px;">
</div>
<button id="settingsButton" class="button" type="submit" style="background-color:transparent; border-color:transparent;">
<img src="img/settings.png" width=30 height=30/>
</button>
<button id="button_mute" class="button" type="submit" style="background-color:transparent; border-color:transparent;">
<img id="button_mute_img"src="img/sound_on.png" width=30 height=30/>
                </button>



                <a>
                    <button id="startButton">Play</button>
                </a>
                <p id="spawnXpLabel">
                </p>
            </div>
            <div id="optionsDiv">
                <button id="closeBut" type="submit" class="button" style="background-color:transparent; border-color:transparent;">
                    <img src="img/x.png" width=35 height=35/>
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
                <div>
                    <label><input type="checkbox" id="options_christmasSkins"><span style="color: #194614;">Use Winter Skins</span></label>
                    <label><input type="checkbox" id="options_noImages"><span style="color: black;">No Animal images  </span></label>
                    <label><input type="checkbox" id="options_noNames"><span style="color: black;">No Names & Chat  </span></label>
                    <label><input type="checkbox" id="options_lowGraphics"><span style="color: black;">Use Low graphics </span></label>
                    <label><input type="checkbox" id="options_noJoystick"><span style="color: #194614;">No Joystick (mobile)</span></label>
                    <label><input type="checkbox" id="options_leftHanded"><span style="color: #194614;">LEFT-handed Joystick</span></label>
                </div>
            </div>




            <!-- curse adex ad & refresh -->
            <div id="adsenseAd">
                <div id='cdm-zone-02'></div>
            </div>
            <!-- mope.io Large Rectangle -->

            <!-- adinplay banner ad 1) -->

        </div>



        <div id="howToPlayDiv">
            <!-- http://www.limaker.com/ -->
            <h2>HOW TO PLAY</h2>
            <ul>
                <li>
                    Click (to run) and 'W' (to swim/use ability)
                </li>
                <li>
                    Press ENTER in-game to chat
                </li>
                <li>Eat players/food outlined LIGHT-GREEN!</li>
                <li>Avoid players outlined RED (They can eat you)!</li>
            </ul>

        </div>
        <div id="updatesDiv">
            <h2>Update(Feb 4) NEW SANDBOX!:</h2>
            <ul>
                <img src="img/mode_sandbox.png" width=124 height=48/>
                <li>-VOTE ON SANDBOX #1 <a href="https://goo.gl/PxUVrv" target="_blank">VOTE HERE</a>:</li>
                <li>-Write your sandbox feedback on reddit <a href="https://www.reddit.com/r/mopeio/comments/5s1eub/sandbox_feedbacksuggestions_and_discussion/" target="_blank">HERE</a>:</li>
                <li>-HOW TO PLAY: Double-click to upgrade your animal at any time! Try out every mope.io animal in full!</li>
                <li>-Any animals can attack any other animals! (Though prey-predator attack damage is only 1/3, no xp is transferred)</li>
                <li>-Leaderboards go by kills instead of xp (since xp can be set by upgrading!)</li>
                <li>-Eating another animal gives you half of it's kills!</li>
                <li>-Leveling up doesn't make you invincible for 3s, and can't be done after being recently hurt</li>
                <li>-Eating any food in-game heals back your health when eating it!</li>
            </ul>

            <h2>Tell us your ideas/bugs: <a  href="https://goo.gl/V0zXYx
            " target="_blank">FEEDBACK FORUM</a></h2>
            <h2>Discuss mopeio:</h2>
            <a href="https://goo.gl/aoECBh" target="_blank">REDDIT PAGE</a>-- <a href="http://www.mope.io/updates.txt" target="_blank">CHANGELOG</a>-
            <a href="https://goo.gl/3ViH9K" target="_blank">IO GAMES</a>
        </div>

        <div id="rightSide">
            <div id="partyLink">
                <a class="partyLinkBut" id="partyLinkOpenBut">Make Party</a>
                <div id="partyLinkClicked" style="display:none;">
                    <p style="">
                        Your friends can join your exact game with this party link:
                    </p>
                    <input type="text" value="...Generating link..." readonly="" id="partyLinkTxt" style="cursor: text; width: 100px; float: left;">
                    <a href="#" class="partyLinkBut" id="partyLinkCopyBut">Copy</a>
                </div>
            </div>
            <div id="shareDiv">

            </div>

            <div id="appsDiv">
                <a id="appAdIOS" href="https://goo.gl/ofAUPJ" target="_blank">
                    <img src="./img/appAd_ios.png" width="132" height="82" alt="GET THE IOS APP!" />
                </a>
                <a id="appAdAndroid" href="https://goo.gl/i3xQWQ" target="_blank">
                    <img src="./img/appAd_and.png" width="132" height="52" alt="GET THE Android APP!" />
                </a>
            </div>
        </div>

    </div>

    <!-- JS (after all elements)-->
    <script src="client.js"></script>


    <!-- google analytics -->
    <script>
        (function(i, s, o, g, r, a, m) {
            i['GoogleAnalyticsObject'] = r;
            i[r] = i[r] || function() {
                (i[r].q = i[r].q || []).push(arguments)
            }, i[r].l = 1 * new Date();
            a = s.createElement(o),
                m = s.getElementsByTagName(o)[0];
            a.async = 1;
            a.src = g;
            m.parentNode.insertBefore(a, m)
        })(window, document, 'script', 'https://www.google-analytics.com/analytics.js', 'ga');

        ga('create', 'UA-36494583-11', 'auto');
        ga('send', 'pageview');
    </script>

    <!-- facebook SDK -->
    <div id="fb-root"></div>
    <script>
        (function(d, s, id) {
            var js, fjs = d.getElementsByTagName(s)[0];
            if (d.getElementById(id)) return;
            js = d.createElement(s);
            js.id = id;
            js.src = "//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.7";
            fjs.parentNode.insertBefore(js, fjs);
        }(document, 'script', 'facebook-jssdk'));
    </script>

    <!-- curse adex (end marker) -->
    <div id='cdm-zone-end'></div>

</body>
<!-- copyright 2016 Stan Tatarnykov, You may use images/videos of mope.io commercially. All rights reserved. -->
<!-- business contact at clickstan@gmail.com-->

</html>
