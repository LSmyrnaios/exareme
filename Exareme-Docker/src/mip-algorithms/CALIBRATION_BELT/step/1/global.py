import sys

from CALIBRATION_BELT import CalibrationBelt

def main(args):
    CalibrationBelt(args[1:]).global_step()

if __name__ == "__main__":
    CalibrationBelt(sys.argv[1:]).global_step()
