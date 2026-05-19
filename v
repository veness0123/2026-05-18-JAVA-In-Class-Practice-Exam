import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import javax.imageio.ImageIO;
import javax.swing.*;

// ==========================================
// 核心影像處理器 (CartoonRenderer)
// ==========================================
class CartoonRenderer {

    // 1. 高斯模糊：平滑影像、消除雜訊
    public BufferedImage gaussianBlur(BufferedImage src) {
        int width = src.getWidth();
        int height = src.getHeight();
        BufferedImage dest = new BufferedImage(width, height, src.getType());
        
        int[][] kernel = {
            {1,  4,  7,  4, 1},
            {4, 16, 26, 16, 4},
            {7, 26, 41, 26, 7},
            {4, 16, 26, 16, 4},
            {1,  4,  7,  4, 1}
        };
        int kernelSum = 273;

        for (int y = 2; y < height - 2; y++) {
            for (int x = 2; x < width - 2; x++) {
                int rSum = 0, gSum = 0, bSum = 0;
                
                for (int ky = -2; ky <= 2; ky++) {
                    for (int kx = -2; kx <= 2; kx++) {
                        int pixel = src.getRGB(x + kx, y + ky);
                        rSum += ((pixel >> 16) & 0xFF) * kernel[ky + 2][kx + 2];
                        gSum += ((pixel >> 8) & 0xFF) * kernel[ky + 2][kx + 2];
                        bSum += (pixel & 0xFF) * kernel[ky + 2][kx + 2];
                    }
                }
                int newPixel = (0xFF << 24) | ((rSum / kernelSum) << 16) | ((gSum / kernelSum) << 8) | (bSum / kernelSum);
                dest.setRGB(x, y, newPixel);
            }
        }
        return dest;
    }

    // 2. Sobel 邊緣檢測：提取黑色的輪廓線
    public boolean[][] detectEdges(BufferedImage src, int threshold) {
        int width = src.getWidth();
        int height = src.getHeight();
        boolean[][] edges = new boolean[width][height];

        int[][] gx = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
        int[][] gy = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

        for (int y = 1; y < height - 1; y++) {
            for (int x = 1; x < width - 1; x++) {
                int valX = 0, valY = 0;

                for (int ky = -1; ky <= 1; ky++) {
                    for (int kx = -1; kx <= 1; kx++) {
                        int pixel = src.getRGB(x + kx, y + ky);
                        int gray = (int)(0.299 * ((pixel >> 16) & 0xFF) + 0.587 * ((pixel >> 8) & 0xFF) + 0.114 * (pixel & 0xFF));
                        valX += gray * gx[ky + 1][kx + 1];
                        valY += gray * gy[ky + 1][kx + 1];
                    }
                }
                edges[x][y] = Math.sqrt((valX * valX) + (valY * valY)) > threshold;
            }
        }
        return edges;
    }

    // 3. 色彩量化：創造平塗色塊效果
    public BufferedImage quantizeColors(BufferedImage src, int numLevels) {
        int width = src.getWidth();
        int height = src.getHeight();
        BufferedImage dest = new BufferedImage(width, height, src.getType());
        int step = 256 / numLevels;

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int pixel = src.getRGB(x, y);
                int r = (((pixel >> 16) & 0xFF) / step) * step + (step / 2);
                int g = (((pixel >> 8) & 0xFF) / step) * step + (step / 2);
                int b = ((pixel & 0xFF) / step) * step + (step / 2);
                dest.setRGB(x, y, (0xFF << 24) | (r << 16) | (g << 8) | b);
            }
        }
        return dest;
    }

    // 4. 卡通化渲染：合併色塊與輪廓
    public BufferedImage renderCartoon(BufferedImage colorImg, boolean[][] edges) {
        int width = colorImg.getWidth();
        int height = colorImg.getHeight();
        BufferedImage result = new BufferedImage(width, height, colorImg.getType());

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                // 如果是邊緣就塗黑，否則保留量化後的顏色
                result.setRGB(x, y, edges[x][y] ? 0xFF000000 : colorImg.getRGB(x, y));
            }
        }
        return result;
    }
}

// ==========================================
// 主程式與視窗畫面 (Java Swing GUI)
// ==========================================
public class CartoonApp extends JFrame {
    private JLabel imageLabel;
    private BufferedImage originalImage;
    private BufferedImage processedImage;
    private CartoonRenderer renderer;

    public CartoonApp() {
        setTitle("魔鷹照片測試 - Traditional Cartoon App");
        setSize(900, 750);
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout());

        renderer = new CartoonRenderer();
        imageLabel = new JLabel("請點擊下方按鈕載入魔鷹的照片...", SwingConstants.CENTER);
        add(new JScrollPane(imageLabel), BorderLayout.CENTER);

        JPanel controlPanel = new JPanel();
        JButton loadBtn = new JButton("載入圖片");
        JButton processBtn = new JButton("套用卡通濾鏡");
        JButton saveBtn = new JButton("儲存圖片");

        controlPanel.add(loadBtn);
        controlPanel.add(processBtn);
        controlPanel.add(saveBtn);
        add(controlPanel, BorderLayout.SOUTH);

        loadBtn.addActionListener(e -> {
            JFileChooser fileChooser = new JFileChooser(".");
            if (fileChooser.showOpenDialog(this) == JFileChooser.APPROVE_OPTION) {
                try {
                    originalImage = ImageIO.read(fileChooser.getSelectedFile());
                    processedImage = null;
                    imageLabel.setIcon(new ImageIcon(getScaledImage(originalImage, 750, 600)));
                    imageLabel.setText("");
                } catch (IOException ex) {
                    JOptionPane.showMessageDialog(this, "讀取圖片失敗！");
                }
            }
        });

        processBtn.addActionListener(e -> {
            if (originalImage == null) {
                JOptionPane.showMessageDialog(this, "請先載入圖片！");
                return;
            }
            // 執行影像處理 Pipeline
            BufferedImage blurred = renderer.gaussianBlur(originalImage);
            boolean[][] edges = renderer.detectEdges(blurred, 45); // 稍微調低閾值，讓細節如字體邊緣更明顯
            BufferedImage quantized = renderer.quantizeColors(blurred, 5); // 分為 5 個色彩階層
            processedImage = renderer.renderCartoon(quantized, edges);

            imageLabel.setIcon(new ImageIcon(getScaledImage(processedImage, 750, 600)));
        });

        saveBtn.addActionListener(e -> {
            if (processedImage == null) return;
            JFileChooser fileChooser = new JFileChooser(".");
            if (fileChooser.showSaveDialog(this) == JFileChooser.APPROVE_OPTION) {
                File file = fileChooser.getSelectedFile();
                if (!file.getName().endsWith(".png")) file = new File(file.getAbsolutePath() + ".png");
                try {
                    ImageIO.write(processedImage, "png", file);
                    JOptionPane.showMessageDialog(this, "儲存成功！");
                } catch (IOException ex) {
                    JOptionPane.showMessageDialog(this, "儲存失敗！");
                }
            }
        });
    }

    private Image getScaledImage(BufferedImage src, int maxWidth, int maxHeight) {
        double ratio = Math.min((double) maxWidth / src.getWidth(), (double) maxHeight / src.getHeight());
        return src.getScaledInstance((int)(src.getWidth() * ratio), (int)(src.getHeight() * ratio), Image.SCALE_SMOOTH);
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> new CartoonApp().setVisible(true));
    }
}
