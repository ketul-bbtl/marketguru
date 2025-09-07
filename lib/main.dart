import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Guru HP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WebViewScreen(),
    );
  }
}

// WebViewScreen - Creates its own WebViewController, supports login!
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  Future<Uint8List> _base64ToImage(String base64String) async {
    // Remove data:image/png;base64, prefix if present
    final normalizedString =
    base64String.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '');
    return base64Decode(normalizedString);
  }

  Future<File> _saveImageToTemp(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/catalogue.png');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  @override
  void initState() {
    super.initState();

    // Set status bar for webview (black icons on white)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ShareChannel',
        onMessageReceived: (JavaScriptMessage message) {
          Share.share(message.message);
        },
      )
      ..addJavaScriptChannel(
        'ClipboardChannel',
        onMessageReceived: (JavaScriptMessage message) {
          Clipboard.setData(ClipboardData(text: message.message));
        },
      )
      ..addJavaScriptChannel(
        'ScreenshotChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final bytes = await _base64ToImage(message.message);
            final temp = await _saveImageToTemp(bytes);
            // Use cross_file XFile for share_plus compatibility
            final shareFile = XFile(temp.path, mimeType: 'image/png');
            await Share.shareXFiles(
              [shareFile],
              text: 'Check out this vehicle!',
            );
          } catch (e) {
            print('Screenshot sharing failed: $e');
          }
        },
      )
    // GalleryChannel: opens native image picker, converts images to dataURLs and delivers to page
      ..addJavaScriptChannel(
        'GalleryChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final ImagePicker picker = ImagePicker();
            // pickMultiImage allows multiple selection; fallback handled by package
            final List<XFile>? picked = await picker.pickMultiImage();
            if (picked == null || picked.isEmpty) {
              return; // user cancelled
            }

            final List<String> jsItems = [];
            for (final p in picked) {
              final bytes = await p.readAsBytes();
              final b64 = base64Encode(bytes);
              final path = p.path.toLowerCase();
              String mime = 'image/jpeg';
              if (path.endsWith('.png')) mime = 'image/png';
              else if (path.endsWith('.webp')) mime = 'image/webp';
              else if (path.endsWith('.gif')) mime = 'image/gif';
              final dataUrl = 'data:$mime;base64,$b64';
              final safeName = p.name.replaceAll("'", "\\'");
              jsItems.add("{name: '${safeName}', data: '${dataUrl}'}");
            }

            final jsArray = '[${jsItems.join(',')}]';

            final callbackJs = """
              (function(){
                try {
                  window.flutterPickedImages = $jsArray;
                  window.dispatchEvent(new Event('flutterPickedImagesReady'));
                } catch(e) {
                  console.error('Error delivering images from Flutter:', e);
                }
              })();
            """;

            await controller.runJavaScript(callbackJs);
          } catch (e) {
            print('GalleryChannel error: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (url) {
            setState(() => isLoading = false);

            // Inject JavaScript: original overrides + html2canvas screenshot logic
            // plus the file-input population script (so page can convert flutterPickedImages into input.files)
            controller.runJavaScript('''
              // Load HTML2Canvas if not already loaded
              if (!window.html2canvas) {
                const script = document.createElement('script');
                script.src = 'https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js';
                document.body.appendChild(script);
              }
              // Override navigator.share if not available
              if (navigator.share === undefined) {
                navigator.share = function(data) {
                  ShareChannel.postMessage(data.url || window.location.href);
                  return Promise.resolve();
                };
              }

              // Override clipboard functionality
              if (navigator.clipboard === undefined) {
                navigator.clipboard = {
                  writeText: function(text) {
                    ClipboardChannel.postMessage(text);
                    return Promise.resolve();
                  }
                };
              }

              // --- BEGIN: file-input population script injected from Flutter ---
              (function() {
                // UPDATED: target the specific input id provided by you
                const fileInputSelector = 'input[type="file"]';

                function dataURLToFile(dataUrl, filename) {
                  const parts = dataUrl.split(',');
                  const meta = parts[0];
                  const base64 = parts[1];
                  const mimeMatch = meta.match(/data:([^;]+);/);
                  const mime = mimeMatch ? mimeMatch[1] : 'application/octet-stream';
                  const byteString = atob(base64);
                  const ab = new ArrayBuffer(byteString.length);
                  const ia = new Uint8Array(ab);
                  for (let i = 0; i < byteString.length; i++) ia[i] = byteString.charCodeAt(i);
                  return new File([ab], filename, { type: mime });
                }

                function populateFileInput(selector) {
                  const items = window.flutterPickedImages || [];
                  if (!items.length) {
                    console.warn('No flutterPickedImages found or empty array.');
                    return;
                  }

                  const dt = new DataTransfer();
                  for (let i = 0; i < items.length; i++) {
                    const it = items[i];
                    try {
                      const name = it.name || ('image_' + i + '.jpg');
                      const file = dataURLToFile(it.data, name);
                      dt.items.add(file);
                    } catch (err) {
                      console.error('Error converting item to file:', err, it);
                    }
                  }

                  let input = document.querySelector(selector);
                  let appendedTemp = false;
                  if (!input) {
                    console.warn('File input not found for selector:', selector, '- creating a hidden fallback input.');
                    input = document.createElement('input');
                    input.type = 'file';
                    input.multiple = true;
                    input.style.display = 'none';
                    document.body.appendChild(input);
                    appendedTemp = true;
                  }

                  try {
                    input.files = dt.files;
                    const ev = new Event('change', { bubbles: true });
                    input.dispatchEvent(ev);
                  } catch (err) {
                    console.error('Failed to set input.files or dispatch change event:', err);
                  } finally {
                    if (appendedTemp) {
                      setTimeout(() => {
                        if (input && input.parentNode) input.parentNode.removeChild(input);
                      }, 3000);
                    }
                  }
                }

                window.addEventListener('flutterPickedImagesReady', function() {
                  populateFileInput(fileInputSelector);
                });

                window.populateFileInputFromFlutter = function(selector) {
                  populateFileInput(selector || fileInputSelector);
                };
              })();
              // --- END: file-input population script ---

              // Add event listener for share / screenshot / gallery buttons
              document.addEventListener('click', function(e) {
                // gallery button - open native picker via Flutter
                const galleryBtn = e.target.closest('#tfcl_choose_gallery_images');
                if (galleryBtn) {
                  e.preventDefault();
                  try {
                    GalleryChannel.postMessage('open');
                  } catch(err) {
                    console.error('GalleryChannel not available', err);
                  }
                  return;
                }

                const shareButton = e.target.closest('#share-my-catalogue-btn');
                const shareCatalogueBtn = e.target.closest('#share-catalogue-btn');
                
                if (shareCatalogueBtn) {
                  e.preventDefault();
                  if (!window.html2canvas) {
                    alert('Screenshot functionality is loading. Please try again in a moment.');
                    return;
                  }

                  // Show loading state
                  const spinner = shareCatalogueBtn.querySelector('.icon-spinner');
                  const shareIcon = shareCatalogueBtn.querySelector('.icon-share');
                  const shareText = shareCatalogueBtn.querySelector('.share-catalogue-text');
                  if (spinner) spinner.style.display = 'inline-block';
                  if (shareIcon) shareIcon.style.opacity = '0.5';
                  if (shareText) shareText.style.opacity = '0.5';
                  shareCatalogueBtn.disabled = true;

                  // Hide elements that shouldn't be in the screenshot
                  const elementsToHide = document.querySelectorAll('.site-header, .site-footer, .share-catalogue-container, .widget-dealer-contact, .list-information, .tfcl-listing-header, .owl-prev, .owl-next, .show-gallery');
                  elementsToHide.forEach(el => { if (el) el.style.display = 'none'; });

                  // Take screenshot after elements are hidden
                  setTimeout(() => {
                    const targetElement = document.querySelector('.site-main');
                    if (!targetElement) {
                      alert('Could not find the content to capture.');
                      return;
                    }

                    html2canvas(targetElement, {
                      useCORS: true,
                      backgroundColor: '#fff',
                      scale: window.devicePixelRatio || 1,
                      allowTaint: false,
                      foreignObjectRendering: false,
                      logging: false,
                      imageTimeout: 0,
                      onclone: function(clonedDoc) {
                        const clonedTarget = clonedDoc.querySelector('.site-main');
                        if (clonedTarget) {
                          // Handle first gallery item explicitly to maintain aspect ratio
                          const originalItem1 = document.querySelector('.item.listing-gallery-item.tfcl-light-gallery.item-1');
                          const clonedItem1 = clonedTarget.querySelector('.item.listing-gallery-item.tfcl-light-gallery.item-1');
                          
                          if (originalItem1 && clonedItem1) {
                            const origRect = originalItem1.getBoundingClientRect();
                            const cropW = origRect.width;
                            const cropH = origRect.height;
                            
                            // Preserve original container styling
                            const origStyle = window.getComputedStyle(originalItem1);
                            clonedItem1.style.position = 'relative';
                            clonedItem1.style.width = cropW + 'px';
                            clonedItem1.style.height = cropH + 'px';
                            clonedItem1.style.overflow = 'hidden';
                            clonedItem1.style.borderRadius = origStyle.borderRadius;
                            clonedItem1.style.border = origStyle.border;
                            clonedItem1.style.backgroundColor = origStyle.backgroundColor;
                            clonedItem1.style.boxShadow = origStyle.boxShadow;
                            clonedItem1.style.maxWidth = 'none';
                            clonedItem1.style.maxHeight = 'none';
                            clonedItem1.style.minWidth = '0';
                            clonedItem1.style.minHeight = '0';

                            const origImg = originalItem1.querySelector('img');
                            const clonedImg = clonedItem1.querySelector('img');
                            
                            if (origImg && clonedImg) {
                              // Force eager loading to ensure dimensions are available
                              clonedImg.loading = 'eager';
                              
                              // Get intrinsic dimensions
                              const naturalW = origImg.naturalWidth || origImg.width || origImg.getBoundingClientRect().width || cropW;
                              const naturalH = origImg.naturalHeight || origImg.height || origImg.getBoundingClientRect().height || cropH;

                              // Calculate ratio to maintain aspect ratio while covering container
                              let ratio;
                              if (naturalW / naturalH > cropW / cropH) {
                                // Image is wider than container - match height
                                ratio = cropH / naturalH;
                              } else {
                                // Image is taller than container - match width
                                ratio = cropW / naturalW;
                              }
                              const displayW = Math.round(naturalW * ratio);
                              const displayH = Math.round(naturalH * ratio);

                              // Center the image within crop box
                              const offsetLeft = Math.round((cropW - displayW) / 2);
                              const offsetTop = Math.round((cropH - displayH) / 2);
                              
                              // Apply precise positioning and dimensions
                              clonedImg.style.position = 'absolute';
                              clonedImg.style.left = offsetLeft + 'px';
                              clonedImg.style.top = offsetTop + 'px';
                              clonedImg.style.width = displayW + 'px';
                              clonedImg.style.height = displayH + 'px';
                              clonedImg.removeAttribute('width');
                              clonedImg.removeAttribute('height');
                              clonedImg.style.maxWidth = 'none';
                              clonedImg.style.maxHeight = 'none';
                              clonedImg.style.minWidth = '0';
                              clonedImg.style.minHeight = '0';
                              clonedImg.style.display = 'block';
                            }
                          }

                          // Handle other images in the target
                          const images = clonedTarget.querySelectorAll('img:not(.item.listing-gallery-item.tfcl-light-gallery.item-1 img)');
                          images.forEach(function(img) {
                            const originalImg = document.querySelector('img[src="' + img.src + '"]');
                            if (originalImg) {
                              const rect = originalImg.getBoundingClientRect();
                              const cs = window.getComputedStyle(originalImg);
                              img.style.width = rect.width + 'px';
                              img.style.height = rect.height + 'px';
                              img.setAttribute('width', Math.round(rect.width));
                              img.setAttribute('height', Math.round(rect.height));
                              img.style.objectFit = cs.objectFit || 'cover';
                              img.style.objectPosition = cs.objectPosition || 'center';
                              img.style.maxWidth = 'none';
                              img.style.maxHeight = 'none';
                              img.style.minWidth = '0';
                              img.style.minHeight = '0';
                              img.style.display = 'block';
                            }
                          });
                        }
                      }
                    }).then(canvas => {
                      // Show hidden elements again
                      elementsToHide.forEach(el => { if (el) el.style.display = ''; });
                      
                      // Reset button state
                      if (spinner) spinner.style.display = 'none';
                      if (shareIcon) shareIcon.style.opacity = '1';
                      if (shareText) shareText.style.opacity = '1';
                      shareCatalogueBtn.disabled = false;

                      // Share the screenshot
                      const imageData = canvas.toDataURL('image/png');
                      ScreenshotChannel.postMessage(imageData);
                    }).catch(error => {
                      console.error('Screenshot failed:', error);
                      alert('Failed to take screenshot. Please try again.');
                      
                      // Show hidden elements again
                      elementsToHide.forEach(el => { if (el) el.style.display = ''; });
                      
                      // Reset button state
                      if (spinner) spinner.style.display = 'none';
                      if (shareIcon) shareIcon.style.opacity = '1';
                      if (shareText) shareText.style.opacity = '1';
                      shareCatalogueBtn.disabled = false;
                    });
                  }, 300);
                } else if (shareButton) {
                  e.preventDefault();
                  const shareUrl = shareButton.getAttribute('data-share-url') || window.location.href;
                  
                  if (navigator.share) {
                    navigator.share({ url: shareUrl })
                      .then(() => {
                        var message = document.getElementById('copy-message');
                        if (message) {
                          message.textContent = 'Link shared!';
                          message.style.color = '#4CAF50';
                          setTimeout(function() {
                            message.textContent = 'Click to share or copy sharable link';
                            message.style.color = '';
                          }, 2000);
                        }
                      })
                      .catch(() => {
                        // Fallback to clipboard
                        navigator.clipboard.writeText(shareUrl);
                      });
                  } else {
                    // Fallback to clipboard
                    navigator.clipboard.writeText(shareUrl);
                  }
                }
              });
            ''');
          },
          onWebResourceError: (_) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://marketguruhp.com'));
  }

  Future<bool> _onWillPop() async {
    if (await controller.canGoBack()) {
      controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: WebViewWidget(controller: controller),
            ),
            if (isLoading) Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}