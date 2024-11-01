<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
				<![CDATA[
var debugFeed = [];
var debugFlag = false;
// Format instant win JSON results.
// @param jsonContext String JSON results to parse and display.
// @param translation Set of Translations for the game.
function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc) {
    var scenario = getScenario(jsonContext);
    var scenarioGrids = scenario.split('|');
    var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function (item) { return item.replace(/\t|\r|\n/gm, "") });
    var prizeNames = (prizeNamesDesc.substring(1)).split(',');

    ////////////////////
    // Parse scenario //
    ////////////////////

    const GRID_COLS = 5;
    const GRID_ROWS = 3;
    const SYMB_DISK = 'P';

    var arrAuditData = [];
    var arrDiskData = [];
    var arrGridData = [];
    var arrGridParts = [];
    var arrGrids = [];
    var objGrid = {};

    function getPhasesData(A_arrGridData, A_arrAuditData) {
        var arrClusters = [];
        var arrPhaseCells = [];
        var arrPhases = [];
        var cellCol = -1;
        var cellRow = -1;
        var objCluster = {};
        var objPhase = {};
        var indexDiskSymb = -1;

        if (A_arrAuditData != '') {
            for (var indexPhase = 0; indexPhase < A_arrAuditData.length; indexPhase++) {
                objPhase = { arrGrid: [], arrClusters: [] };

                for (var indexCol = 0; indexCol < GRID_COLS; indexCol++) {
                    objPhase.arrGrid.push(A_arrGridData[indexCol].substr(0, GRID_ROWS));
                }

                arrClusters = A_arrAuditData[indexPhase].split(';');
                arrPhaseCells = [];

                for (var indexCluster = 0; indexCluster < arrClusters.length; indexCluster++) {
                    objCluster = { strPrefix: '', arrCells: [] };

                    objCluster.strPrefix = arrClusters[indexCluster][0];
                    objCluster.arrCells = arrClusters[indexCluster].slice(1).match(new RegExp('.{1,2}', 'g')).map(function (item) { return parseInt(item, 10); });

                    objPhase.arrClusters.push(objCluster);

                    arrPhaseCells = arrPhaseCells.concat(objCluster.arrCells);
                }

                arrPhases.push(objPhase);

                arrPhaseCells.sort(function (a, b) { return b - a; });

                for (var indexCell = 0; indexCell < arrPhaseCells.length; indexCell++) {
                    if (indexCell == 0 || (indexCell > 0 && arrPhaseCells[indexCell] != arrPhaseCells[indexCell - 1])) {
                        cellCol = Math.floor((arrPhaseCells[indexCell] - 1) / GRID_ROWS);
                        cellRow = (arrPhaseCells[indexCell] - 1) % GRID_ROWS;

                        if (cellCol >= 0 && cellCol < GRID_COLS) {
                            A_arrGridData[cellCol] = A_arrGridData[cellCol].substring(0, cellRow) + A_arrGridData[cellCol].substring(cellRow + 1);
                        }
                    }
                }
            }
        }

        objPhase = { arrGrid: [], arrClusters: [] };

        for (var indexCol = 0; indexCol < GRID_COLS; indexCol++) {
            objPhase.arrGrid.push(A_arrGridData[indexCol].substr(0, GRID_ROWS));
        }

        if (objPhase.arrGrid.join('').replace(new RegExp('[^' + SYMB_DISK + ']', 'g'), '').length > 0) {
            objCluster = { strPrefix: '', arrCells: [] };

            objCluster.strPrefix = SYMB_DISK;

            for (var indexCol = 0; indexCol < GRID_COLS; indexCol++) {
                indexDiskSymb = objPhase.arrGrid[indexCol].indexOf(SYMB_DISK);

                if (indexDiskSymb != -1) {
                    objCluster.arrCells.push(indexCol * GRID_ROWS + indexDiskSymb + 1);
                }
            }

            objPhase.arrClusters.push(objCluster);
        }

        arrPhases.push(objPhase);

        return arrPhases;
    }

    function getDiskData(A_arrDiskData, A_arrGridData) {
        var arrPrizes = [];
        var objDiskPrize = {};

        for (var indexPrize = 0; indexPrize < A_arrDiskData.length; indexPrize++) {
            objDiskPrize = { sPrize: '', bMatched: false };

            objDiskPrize.sPrize = A_arrDiskData[indexPrize];
            objDiskPrize.bMatched = (A_arrGridData[indexPrize].indexOf(SYMB_DISK) != -1);

            arrPrizes.push(objDiskPrize);
        }

        return arrPrizes;
    }

    for (var indexGrid = 0; indexGrid < scenarioGrids.length - 1; indexGrid++) {
        objGrid = { arrDiskPrizes: [], arrPhases: [] };

        arrGridParts = scenarioGrids[indexGrid].split(':');
        arrDiskData = arrGridParts[0].split(',');
        arrGridData = arrGridParts[1].split(',');
        arrAuditData = arrGridParts[2].split(',');

        objGrid.arrPhases = getPhasesData(arrGridData, arrAuditData);
        objGrid.arrDiskPrizes = getDiskData(arrDiskData, objGrid.arrPhases[objGrid.arrPhases.length - 1].arrGrid);

        arrGrids.push(objGrid);
    }

    /////////////////////////
    // Currency formatting //
    /////////////////////////

    var bCurrSymbAtFront = false;
    var strCurrSymb = '';
    var strDecSymb = '';
    var strThouSymb = '';

    function getCurrencyInfoFromTopPrize() {
        var topPrize = convertedPrizeValues[0];
        var strPrizeAsDigits = topPrize.replace(new RegExp('[^0-9]', 'g'), '');
        var iPosFirstDigit = topPrize.indexOf(strPrizeAsDigits[0]);
        var iPosLastDigit = topPrize.lastIndexOf(strPrizeAsDigits.substr(-1));
        bCurrSymbAtFront = (iPosFirstDigit != 0);
        strCurrSymb = (bCurrSymbAtFront) ? topPrize.substr(0, iPosFirstDigit) : topPrize.substr(iPosLastDigit + 1);
        var strPrizeNoCurrency = topPrize.replace(new RegExp('[' + strCurrSymb + ']', 'g'), '');
        var strPrizeNoDigitsOrCurr = strPrizeNoCurrency.replace(new RegExp('[0-9]', 'g'), '');
        strDecSymb = strPrizeNoDigitsOrCurr.substr(-1);
        strThouSymb = (strPrizeNoDigitsOrCurr.length > 1) ? strPrizeNoDigitsOrCurr[0] : strThouSymb;
    }

    function getPrizeInCents(AA_strPrize) {
        return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
    }

    function getCentsInCurr(AA_iPrize) {
        var strValue = AA_iPrize.toString();

        strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
        strValue = strValue.substr(0, strValue.length - 2) + strDecSymb + strValue.substr(-2);
        strValue = (strValue.length > 6) ? strValue.substr(0, strValue.length - 6) + strThouSymb + strValue.substr(-6) : strValue;
        strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

        return strValue;
    }

    getCurrencyInfoFromTopPrize();

    ///////////////
    // UI Config //
    ///////////////

    const COLOUR_BLACK = '#000000';
    const COLOUR_BLUE = '#99ccff';
    const COLOUR_BROWN = '#990000';
    const COLOUR_GREEN = '#00cc00';
    const COLOUR_LEMON = '#ffff99';
    const COLOUR_LILAC = '#ccccff';
    const COLOUR_LIME = '#ccff99';
    const COLOUR_NAVY = '#0000ff';
    const COLOUR_ORANGE = '#ffcc99';
    const COLOUR_PINK = '#ffccff';
    const COLOUR_PURPLE = '#cc99ff';
    const COLOUR_RED = '#ff9999';
    const COLOUR_SCARLET = '#ff0000';
    const COLOUR_WHITE = '#ffffff';
    const COLOUR_YELLOW = '#ffff00';

    const PRIZE_COLOURS = [COLOUR_RED, COLOUR_ORANGE, COLOUR_LEMON, COLOUR_LIME, COLOUR_BLUE, COLOUR_LILAC, COLOUR_PURPLE, COLOUR_PINK];
    const SPECIAL_COLOURS_BOX = [COLOUR_SCARLET, COLOUR_BLACK];
    const SPECIAL_COLOURS_TEXT = [COLOUR_YELLOW, COLOUR_WHITE];

    const SYMB_PRIZES = 'ABCDEFGH';
    const SYMB_WILD = 'W';
    const SYMB_SPECIALS = SYMB_DISK + SYMB_WILD;

    const CELL_SIZE = 24;
    const CELL_MARGIN = 1;
    const CELL_TEXT_X = 13;
    const CELL_TEXT_Y = 15;
    const IS_PRIZE_DISK = true;

    var r = [];

    var boxColourStr = '';
    var canvasIdStr = '';
    var elementStr = '';
    var textColourStr = '';

    function showSymb(A_strCanvasId, A_strCanvasElement, A_strBoxColour, A_strTextColour, A_strText) {
        var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
        var gridCanvasWidth = (A_strText.length == 1) ? CELL_SIZE : CELL_SIZE + 12;
        var textPosX = (A_strText.length == 1) ? CELL_TEXT_X : CELL_TEXT_X + 6;

        r.push('<canvas id="' + A_strCanvasId + '" width="' + (gridCanvasWidth + 2 * CELL_MARGIN).toString() + '" height="' + (CELL_SIZE + 2 * CELL_MARGIN).toString() + '"></canvas>');
        r.push('<script>');
        r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
        r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
        r.push(canvasCtxStr + '.font = "bold 14px Arial";');
        r.push(canvasCtxStr + '.textAlign = "center";');
        r.push(canvasCtxStr + '.textBaseline = "middle";');
        r.push(canvasCtxStr + '.strokeRect(' + (CELL_MARGIN + 0.5).toString() + ', ' + (CELL_MARGIN + 0.5).toString() + ', ' + gridCanvasWidth.toString() + ', ' + CELL_SIZE.toString() + ');');
        r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
        r.push(canvasCtxStr + '.fillRect(' + (CELL_MARGIN + 1.5).toString() + ', ' + (CELL_MARGIN + 1.5).toString() + ', ' + (gridCanvasWidth - 2).toString() + ', ' + (CELL_SIZE - 2).toString() + ');');
        r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
        r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + textPosX.toString() + ', ' + CELL_TEXT_Y.toString() + ');');
        r.push('</script>');
    }

    function showGridSymbs(A_strCanvasId, A_strCanvasElement, A_arrGrid, A_bPrizeDisk, A_bLastPhase) {
        var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
        var cellX = 0;
        var cellY = 0;
        var isPrizeCell = false;
        var isSpecialCell = false;
        var symbCell = '';
        var symbIndex = -1;
        var gridRows = (A_bPrizeDisk) ? 1 : A_arrGrid[0].length;
        var gridCanvasHeight = gridRows * CELL_SIZE + 2 * CELL_MARGIN;
        var gridCanvasWidth = GRID_COLS * CELL_SIZE + 2 * CELL_MARGIN;
        var textSize = 0;
        var winDiskPrize = false;

        r.push('<canvas id="' + A_strCanvasId + '" width="' + gridCanvasWidth.toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
        r.push('<script>');
        r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
        r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
        r.push(canvasCtxStr + '.textAlign = "center";');
        r.push(canvasCtxStr + '.textBaseline = "middle";');

        for (var gridCol = 0; gridCol < GRID_COLS; gridCol++) {
            for (var gridRow = 0; gridRow < gridRows; gridRow++) {
                symbCell = (A_bPrizeDisk) ? SYMB_DISK : A_arrGrid[gridCol][gridRow];
                winDiskPrize = (A_bPrizeDisk && A_bLastPhase && A_arrGrid[gridCol].bMatched);
                isPrizeCell = (SYMB_PRIZES.indexOf(symbCell) != -1);
                isSpecialCell = (!A_bPrizeDisk && SYMB_SPECIALS.indexOf(symbCell) != -1);
                symbIndex = (isPrizeCell) ? SYMB_PRIZES.indexOf(symbCell) : ((isSpecialCell || winDiskPrize) ? SYMB_SPECIALS.indexOf(symbCell) : -1);
                boxColourStr = (isPrizeCell) ? PRIZE_COLOURS[symbIndex] : ((isSpecialCell || winDiskPrize) ? SPECIAL_COLOURS_BOX[symbIndex] : COLOUR_WHITE);
                textColourStr = (isSpecialCell || winDiskPrize) ? SPECIAL_COLOURS_TEXT[symbIndex] : COLOUR_BLACK;
                cellX = gridCol * CELL_SIZE;
                cellY = (gridRows - gridRow - 1) * CELL_SIZE;
                textSize = (A_bPrizeDisk) ? 11 : 14;
                symbCell = (A_bPrizeDisk) ? A_arrGrid[gridCol].sPrize : symbCell;

                r.push(canvasCtxStr + '.font = "bold ' + textSize.toString() + 'px Arial";');
                r.push(canvasCtxStr + '.strokeRect(' + (cellX + CELL_MARGIN + 0.5).toString() + ', ' + (cellY + CELL_MARGIN + 0.5).toString() + ', ' + CELL_SIZE.toString() + ', ' + CELL_SIZE.toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
                r.push(canvasCtxStr + '.fillRect(' + (cellX + CELL_MARGIN + 1.5).toString() + ', ' + (cellY + CELL_MARGIN + 1.5).toString() + ', ' + (CELL_SIZE - 2).toString() + ', ' + (CELL_SIZE - 2).toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
                r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + CELL_TEXT_X).toString() + ', ' + (cellY + CELL_TEXT_Y).toString() + ');');
            }
        }

        r.push('</script>');
    }

    function showAuditSymbs(A_strCanvasId, A_strCanvasElement, A_arrGrid, A_arrData) {
        var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
        var cellX = 0;
        var cellY = 0;
        var isClusterCell = false;
        var isPrizeCell = false;
        var isSpecialCell = false;
        var isWildCell = false;
        var symbCell = '';
        var symbIndex = -1;
        var cellNum = 0;

        var gridCanvasHeight = GRID_ROWS * CELL_SIZE + 2 * CELL_MARGIN;
        var gridCanvasWidth = GRID_COLS * CELL_SIZE + 2 * CELL_MARGIN;

        r.push('<canvas id="' + A_strCanvasId + '" width="' + (gridCanvasWidth + 25).toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
        r.push('<script>');
        r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
        r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
        r.push(canvasCtxStr + '.textAlign = "center";');
        r.push(canvasCtxStr + '.textBaseline = "middle";');

        for (var gridCol = 0; gridCol < GRID_COLS; gridCol++) {
            for (var gridRow = 0; gridRow < GRID_ROWS; gridRow++) {
                cellNum++;

                isClusterCell = (A_arrData.arrCells.indexOf(cellNum) != -1);
                isWildCell = (isClusterCell && A_arrGrid[gridCol][gridRow] == SYMB_WILD);
                isSpecialCell = (isWildCell || (isClusterCell && SYMB_SPECIALS.indexOf(A_arrData.strPrefix) != -1));
                isPrizeCell = (!isSpecialCell && isClusterCell && SYMB_PRIZES.indexOf(A_arrData.strPrefix) != -1);
                symbIndex = (isPrizeCell) ? SYMB_PRIZES.indexOf(A_arrData.strPrefix) : ((isSpecialCell) ? ((isWildCell) ? SYMB_SPECIALS.indexOf(SYMB_WILD) : SYMB_SPECIALS.indexOf(A_arrData.strPrefix)) : -1);
                boxColourStr = (isPrizeCell) ? PRIZE_COLOURS[symbIndex] : ((isSpecialCell) ? SPECIAL_COLOURS_BOX[symbIndex] : COLOUR_WHITE);
                textColourStr = (isSpecialCell) ? SPECIAL_COLOURS_TEXT[symbIndex] : COLOUR_BLACK;
                cellX = gridCol * CELL_SIZE;
                cellY = (GRID_ROWS - gridRow - 1) * CELL_SIZE;
                symbCell = ('0' + cellNum).slice(-2);

                r.push(canvasCtxStr + '.font = "bold 14px Arial";');
                r.push(canvasCtxStr + '.strokeRect(' + (cellX + CELL_MARGIN + 0.5).toString() + ', ' + (cellY + CELL_MARGIN + 0.5).toString() + ', ' + CELL_SIZE.toString() + ', ' + CELL_SIZE.toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
                r.push(canvasCtxStr + '.fillRect(' + (cellX + CELL_MARGIN + 1.5).toString() + ', ' + (cellY + CELL_MARGIN + 1.5).toString() + ', ' + (CELL_SIZE - 2).toString() + ', ' + (CELL_SIZE - 2).toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
                r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + CELL_TEXT_X).toString() + ', ' + (cellY + CELL_TEXT_Y).toString() + ');');
            }
        }

        r.push('</script>');
    }

    ///////////////////////
    // Prize Symbols Key //
    ///////////////////////

    var symbDesc = '';
    var symbPrize = '';
    var symbSpecial = '';

    r.push('<div style="float:left; margin-right:50px">');
    r.push('<p>' + getTranslationByName("titlePrizeSymbolsKey", translations) + '</p>');

    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
    r.push('<tr class="tablehead">');
    r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
    r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
    r.push('</tr>');

    for (var indexPrize = 0; indexPrize < SYMB_PRIZES.length; indexPrize++) {
        symbPrize = SYMB_PRIZES[indexPrize];
        canvasIdStr = 'cvsKeySymb' + symbPrize;
        elementStr = 'eleKeySymb' + symbPrize;
        boxColourStr = PRIZE_COLOURS[indexPrize];
        symbDesc = 'symb' + symbPrize;

        r.push('<tr class="tablebody">');
        r.push('<td align="center">');

        showSymb(canvasIdStr, elementStr, boxColourStr, COLOUR_BLACK, symbPrize);

        r.push('</td>');
        r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
        r.push('</tr>');
    }

    r.push('</table>');
    r.push('</div>');

    /////////////////////////
    // Special Symbols Key //
    /////////////////////////

    r.push('<div style="float:left">');
    r.push('<p>' + getTranslationByName("titleSpecialSymbolsKey", translations) + '</p>');

    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
    r.push('<tr class="tablehead">');
    r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
    r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
    r.push('</tr>');

    for (var indexSpecial = 0; indexSpecial < SYMB_SPECIALS.length; indexSpecial++) {
        symbSpecial = SYMB_SPECIALS[indexSpecial];
        canvasIdStr = 'cvsKeySymb' + symbSpecial;
        elementStr = 'eleKeySymb' + symbSpecial;
        boxColourStr = SPECIAL_COLOURS_BOX[indexSpecial];
        textColourStr = SPECIAL_COLOURS_TEXT[indexSpecial];
        symbDesc = 'symb' + symbSpecial;

        r.push('<tr class="tablebody">');
        r.push('<td align="center">');

        showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, symbSpecial);

        r.push('</td>');
        r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
        r.push('</tr>');
    }

    r.push('</table>');
    r.push('</div>');

    r.push('<div style="clear:both">');

    ///////////
    // Grids //
    ///////////

    const FREE_PLAYS = 'FP';
    const JACKPOT_PREFIX = 'J';

    var countText = '';
    var freePlayAdd = 0;
    var gridStr = '';
    var gridWin = 0;
    var isJackpot = false;
    var isLastPhase = false;
    var isMainGrid = false;
    var isPrizeDoubled = false;
    var phaseStr = '';
    var prefixIndex = -1;
    var prizeCount = 0;
    var prizeStr = '';
    var prizeText = '';
    var prizeVal = '';
    var totalFreePlays = 0;

    for (var indexGrid = 0; indexGrid < arrGrids.length; indexGrid++) {
        isMainGrid = (indexGrid == 0);
        gridWin = 0;

        gridStr = (isMainGrid) ? getTranslationByName("mainGrid", translations) :
            (getTranslationByName("freePlay", translations) + ' ' + indexGrid.toString() + ' / ' + totalFreePlays.toString());

        r.push('<p><br>' + gridStr.toUpperCase() + '</p>');

        r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

        for (var indexPhase = 0; indexPhase < arrGrids[indexGrid].arrPhases.length; indexPhase++) {
            isLastPhase = (indexPhase + 1 == arrGrids[indexGrid].arrPhases.length);

            r.push('<tr class="tablebody">');

            ////////////////
            // Phase Info //
            ////////////////

            phaseStr = getTranslationByName("phaseNum", translations) + ' ' + (indexPhase + 1).toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' +
                arrGrids[indexGrid].arrPhases.length.toString();

            r.push('<td valign="top">' + phaseStr + '</td>');

            //////////
            // Grid //
            //////////

            r.push('<td style="padding-left:50px; padding-right:50px; padding-bottom:25px">');
            r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
            r.push('<tr class="tablebody">');
            r.push('<td style="padding-bottom:10px">');

            canvasIdStr = 'cvsDisk' + indexGrid.toString() + '_' + indexPhase.toString();
            elementStr = 'eleDisk' + indexGrid.toString() + '_' + indexPhase.toString();

            showGridSymbs(canvasIdStr, elementStr, arrGrids[indexGrid].arrDiskPrizes, IS_PRIZE_DISK, isLastPhase);

            r.push('</td>');
            r.push('</tr>');
            r.push('<tr class="tablebody">');
            r.push('<td>');

            canvasIdStr = 'cvsGrid' + indexGrid.toString() + '_' + indexPhase.toString();
            elementStr = 'eleGrid' + indexGrid.toString() + '_' + indexPhase.toString();

            showGridSymbs(canvasIdStr, elementStr, arrGrids[indexGrid].arrPhases[indexPhase].arrGrid, !IS_PRIZE_DISK, isLastPhase);

            r.push('</td>');
            r.push('</tr>');
            r.push('</table>');
            r.push('</td>');

            ///////////////////////////
            // Clusters and Specials //
            ///////////////////////////

            r.push('<td style="padding-right:50px; padding-bottom:25px">');
            r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
            r.push('<tr class="tablebody">');

            for (var indexCluster = 0; indexCluster < arrGrids[indexGrid].arrPhases[indexPhase].arrClusters.length; indexCluster++) {
                r.push('<td>');
                r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
                r.push('<tr class="tablebody">');
                r.push('<td style="padding-bottom:10px">');

                canvasIdStr = 'cvsDisk' + indexGrid.toString() + '_' + indexPhase.toString() + '_' + indexCluster.toString();
                elementStr = 'eleDisk' + indexGrid.toString() + '_' + indexPhase.toString() + '_' + indexCluster.toString();

                showGridSymbs(canvasIdStr, elementStr, arrGrids[indexGrid].arrDiskPrizes, IS_PRIZE_DISK, isLastPhase);

                r.push('</td>');
                r.push('</tr>');
                r.push('<tr class="tablebody">');
                r.push('<td>');

                canvasIdStr = 'cvsAudit' + indexGrid.toString() + '_' + indexPhase.toString() + '_' + indexCluster.toString();
                elementStr = 'eleAudit' + indexGrid.toString() + '_' + indexPhase.toString() + '_' + indexCluster.toString();

                showAuditSymbs(canvasIdStr, elementStr, arrGrids[indexGrid].arrPhases[indexPhase].arrGrid, arrGrids[indexGrid].arrPhases[indexPhase].arrClusters[indexCluster]);

                r.push('</td>');
                r.push('</tr>');
                r.push('</table>');
                r.push('</td>');
            }

            r.push('</tr>');
            r.push('</table>');
            r.push('</td>');

            /////////////////////
            // Prizes and Text //
            /////////////////////

            r.push('<td valign="top" style="padding-bottom:25px">');

            if (!isLastPhase && arrGrids[indexGrid].arrPhases[indexPhase].arrClusters.length > 0) {
                r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

                for (var indexCluster = 0; indexCluster < arrGrids[indexGrid].arrPhases[indexPhase].arrClusters.length; indexCluster++) {
                    symbPrize = arrGrids[indexGrid].arrPhases[indexPhase].arrClusters[indexCluster].strPrefix;
                    canvasIdStr = 'cvsClusterPrize' + indexGrid.toString() + '_' + indexPhase.toString() + '_' + indexCluster.toString() + symbPrize;
                    elementStr = 'eleClusterPrize' + indexGrid.toString() + '_' + indexPhase.toString() + '_' + indexCluster.toString() + symbPrize;
                    prefixIndex = SYMB_PRIZES.indexOf(symbPrize);
                    boxColourStr = PRIZE_COLOURS[prefixIndex];
                    prizeCount = arrGrids[indexGrid].arrPhases[indexPhase].arrClusters[indexCluster].arrCells.length;
                    countText = prizeCount.toString() + ' x';
                    prizeText = symbPrize + prizeCount.toString();
                    prizeVal = getPrizeInCents(convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)]);
                    isPrizeDoubled = (!isMainGrid && 'ABCD'.indexOf(symbPrize) != -1);
                    prizeVal = (isPrizeDoubled) ? 2 * prizeVal : prizeVal;
                    prizeStr = ((isPrizeDoubled) ? 'x 2 ' : '') + '= ' + getCentsInCurr(prizeVal);
                    gridWin += prizeVal;

                    r.push('<tr class="tablebody">');
                    r.push('<td align="right">' + countText + '</td>');
                    r.push('<td align="center">');

                    showSymb(canvasIdStr, elementStr, boxColourStr, COLOUR_BLACK, symbPrize);

                    r.push('</td>');
                    r.push('<td>' + prizeStr + '</td>');
                    r.push('</tr>');
                }

                r.push('</table>');
            }

            if (isLastPhase) {
                if (arrGrids[indexGrid].arrPhases[indexPhase].arrClusters.length > 0) {
                    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

                    for (var indexDiskPrize = 0; indexDiskPrize < arrGrids[indexGrid].arrDiskPrizes.length; indexDiskPrize++) {
                        if (arrGrids[indexGrid].arrDiskPrizes[indexDiskPrize].bMatched) {
                            canvasIdStr = 'cvsDiskPrize' + indexGrid.toString() + '_' + indexDiskPrize.toString();
                            elementStr = 'eleDiskPrize' + indexGrid.toString() + '_' + indexDiskPrize.toString();
                            boxColourStr = SPECIAL_COLOURS_BOX[SYMB_SPECIALS.indexOf(SYMB_DISK)];
                            textColourStr = SPECIAL_COLOURS_TEXT[SYMB_SPECIALS.indexOf(SYMB_DISK)];
                            prizeText = arrGrids[indexGrid].arrDiskPrizes[indexDiskPrize].sPrize;
                            isJackpot = (prizeText[0] == JACKPOT_PREFIX);
                            freePlayAdd = (isMainGrid) ? 10 : 2;
                            totalFreePlays += (prizeText == FREE_PLAYS) ? freePlayAdd : 0;

                            prizeStr = '= ' + ((isJackpot) ? getTranslationByName("jackpot", translations) + ' ' + prizeText[1].toString() :
                                ((prizeText == FREE_PLAYS) ? freePlayAdd.toString() + ' ' + ((!isMainGrid) ? getTranslationByName("freePlayExtra", translations) + ' ' : '') +
                                 getTranslationByName("freePlayTurns", translations) :
                                    convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)]));

                            gridWin += (prizeText == FREE_PLAYS || isJackpot) ? 0 : getPrizeInCents(convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)]);

                            r.push('<tr class="tablebody">');
                            r.push('<td align="center">');

                            showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, prizeText);

                            r.push('</td>');
                            r.push('<td>' + prizeStr + '</td>');
                            r.push('</tr>');
                        }
                    }

                    r.push('</table>');
                }

                if (gridWin > 0) {
                    prizeStr = getCentsInCurr(gridWin);

                    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
                    r.push('<tr class="tablebody">');
                    r.push('<td>' + getTranslationByName("gridWin", translations) + ' : ' + prizeStr + '</td>');
                    r.push('</tr>');
                    r.push('</table>');
                }
            }

            r.push('</td>');
            r.push('</tr>');
        }

        r.push('</table>');
    }

    r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// !DEBUG OUTPUT TABLE
						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						if(debugFlag)
						{
							//////////////////////////////////////
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							for(var idx = 0; idx < debugFeed.length; ++idx)
	 						{
								if(debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
 								r.push('</tr>');
							}
							r.push('</table>');
						}
						return r.join('');
					}

					function getScenario(jsonContext)
					{
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");

						for(var i = 0; i < pricePoints.length; ++i)
						{
							if(wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}
						return "";
					}

					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;
						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; ++i)
						{
							if(prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}

					/////////////////////////////////////////////////////////////////////////////////////////
					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if(childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
				]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="SignedData/Data/Outcome/ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			

				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>				
				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
						<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
