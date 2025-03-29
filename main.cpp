#include <QApplication>
#include <QMainWindow>
#include <QPushButton>
#include <QProcess>
#include <QVBoxLayout>
#include <QLabel>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QMessageBox>
#include <QTimer>
#include <QCommandLineParser>

class PowerManager : public QMainWindow {
    Q_OBJECT

public:
    explicit PowerManager(QWidget *parent = nullptr) : QMainWindow(parent) {
        setupUI();
        loadState();
        setupConnections();
        QTimer::singleShot(1000, this, &PowerManager::verifySystemState);
    }

    bool verifySystemState() {
        QFile turboFile("/sys/devices/system/cpu/intel_pstate/no_turbo");
        if (turboFile.open(QIODevice::ReadOnly)) {
            QTextStream in(&turboFile);
            QString state = in.readLine().trimmed();
            bool newState = (state == "1");
            if (newState != isPowerSaveActive) {
                updatePowerState(newState);
                saveState(newState);
            }
            return newState;
        }
        return false;
    }

public slots:
    void applyPowerSave() {
        toggleButton->setEnabled(false);
        statusLabel->setText("Activating power save...");

        if (executeScript("/usr/local/bin/power_save_script.sh")) {
            updatePowerState(true);
        } else {
            displayErrorMessage("Failed to activate power save mode");
        }
        toggleButton->setEnabled(true);
    }

    void restoreNormalPower() {
        toggleButton->setEnabled(false);
        statusLabel->setText("Restoring normal mode...");

        if (executeScript("/usr/local/bin/restore_power_script.sh")) {
            updatePowerState(false);
        } else {
            displayErrorMessage("Failed to restore normal mode");
        }
        toggleButton->setEnabled(true);
    }

private:
    QPushButton *toggleButton;
    QLabel *statusLabel;
    bool isPowerSaveActive = false;

    void setupUI() {
        QWidget *centralWidget = new QWidget(this);
        QVBoxLayout *layout = new QVBoxLayout(centralWidget);

        toggleButton = new QPushButton("Enable Power Save", this);
        statusLabel = new QLabel("Status: Normal Mode", this);

        layout->addWidget(toggleButton);
        layout->addWidget(statusLabel);

        setCentralWidget(centralWidget);
        setWindowTitle("Dorimon Power Manager");
        resize(320, 160);
    }

    void setupConnections() {
        connect(toggleButton, &QPushButton::clicked, this, [this]() {
            isPowerSaveActive ? restoreNormalPower() : applyPowerSave();
        });
    }

    bool executeScript(const QString &scriptPath) {
        QProcess process;
        process.start("pkexec", {"sh", scriptPath});
        if (!process.waitForFinished(5000)) {
            process.kill();
            return false;
        }
        return process.exitCode() == 0;
    }

    void updatePowerState(bool active) {
        isPowerSaveActive = active;
        toggleButton->setText(active ? "Disable Power Save" : "Enable Power Save");
        statusLabel->setText(active ? "Status: POWER SAVE ACTIVE" : "Status: NORMAL MODE");
        saveState(active);
    }

    void saveState(bool state) {
        QFile file(QDir::homePath() + "/.dorimon.conf");
        if (file.open(QIODevice::WriteOnly)) {
            QTextStream out(&file);
            out << (state ? "1" : "0");
        }
    }

    void loadState() {
        QFile file(QDir::homePath() + "/.dorimon.conf");
        if (file.exists() && file.open(QIODevice::ReadOnly)) {
            QTextStream in(&file);
            updatePowerState(in.readLine().trimmed() == "1");
        }
    }

    void displayErrorMessage(const QString &message) {
        QMessageBox::critical(this, "Operation Failed", message);
    }
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    QCommandLineParser parser;
    parser.addOption({"startup", "Apply saved state on system startup"});
    parser.process(app);

    if (parser.isSet("startup")) {
        PowerManager manager;
        if (manager.verifySystemState()) {
            manager.applyPowerSave();
        }
        return 0;
    }

    PowerManager window;
    window.show();
    return app.exec();
}

#include "main.moc"
