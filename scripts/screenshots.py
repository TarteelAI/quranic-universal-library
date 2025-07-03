from appium import webdriver
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.actions import interaction
from selenium.webdriver.common.actions.action_builder import ActionBuilder
from selenium.webdriver.common.actions.pointer_input import PointerInput
from appium.options.ios import XCUITestOptions
from appium.options.android import UiAutomator2Options
import time
import os
import urllib3
import json
from tqdm import tqdm

LAYOUT = "v1-optimized"
FROM_PAGE = 174
TO_PAGE = 176
PLATFORM = 'android'  # Change to 'android' for Android testing
PLATFORM_VERSION = 'Pixel_6_API_33_RAM_8GB'  # Update this to match your simulator/emulator
DEVICE_NAME = 'iPhone 16'  # Update this for Android or iOS
SCREENSHOT_PATH = f"/Volumes/Development/tarteel/mushaf-verification/sample/{LAYOUT}"

class MushafScreenshotAutomation:
    def __init__(self, layout="unknown", platform='ios'):
        self.platform = platform
        self.server_url = 'http://localhost:4723'
        self.driver = None
        self.screenshot_dir = SCREENSHOT_PATH

        if not os.path.exists(self.screenshot_dir):
            os.makedirs(self.screenshot_dir)

        if platform == 'ios':
            self.options = XCUITestOptions()
            self.options.platform_name = 'iOS'
            self.options.platform_version = PLATFORM_VERSION
            self.options.device_name = DEVICE_NAME
            self.options.automation_name = 'XCUITest'
            self.options.bundle_id = 'com.iqraapp.Iqra'
        else:
            self.options = UiAutomator2Options()
            self.options.platform_name = 'Android'

        self.options.no_reset = True
        self.options.full_reset = False

    def check_appium_server(self):
        try:
            http = urllib3.PoolManager()
            response = http.request('GET', f'{self.server_url}/status')
            data = json.loads(response.data.decode('utf-8'))
            return 'value' in data and 'ready' in data['value']
        except Exception as e:
            print(f"Failed to connect to Appium server: {str(e)}")
            return False

    def connect(self):
        if not self.check_appium_server():
            raise ConnectionError("Appium server is not running. Please start it with 'appium' command.")

        try:
            self.driver = webdriver.Remote(self.server_url, options=self.options)
            self.window_size = self.driver.get_window_size()
            self.width = self.window_size['width']
            self.height = self.window_size['height']

            # Precompute swipe coordinates once
            self.swipe_coords = {
              'left': {'start_x': self.width * 0.9, 'start_y': self.height * 0.5, 'end_x': self.width * 0.1, 'end_y': self.height * 0.5},
              'right': {'start_x': self.width * 0.1, 'start_y': self.height * 0.5, 'end_x': self.width * 0.9, 'end_y': self.height * 0.5},
              'up': {'start_x': self.width * 0.5, 'start_y': self.height * 0.8, 'end_x': self.width * 0.5, 'end_y': self.height * 0.2},
              'down': {'start_x': self.width * 0.5, 'start_y': self.height * 0.2, 'end_x': self.width * 0.5, 'end_y': self.height * 0.8}
            }
            return True
        except Exception as e:
            print(f"Failed to connect to Appium server: {str(e)}")
            return False

    def swipe_screen(self, direction='left'):
        coords = self.swipe_coords.get(direction.lower())
        if not coords:
            raise ValueError(f"Invalid direction: {direction}")

        actions = ActionChains(self.driver)
        pointer = PointerInput(interaction.POINTER_TOUCH, "touch")
        actions.w3c_actions = ActionBuilder(self.driver, mouse=pointer)
        actions.w3c_actions.pointer_action.move_to_location(coords['start_x'], coords['start_y'])
        actions.w3c_actions.pointer_action.pointer_down()
        actions.w3c_actions.pointer_action.pause(0.25)
        actions.w3c_actions.pointer_action.move_to_location(coords['end_x'], coords['end_y'])
        actions.w3c_actions.pointer_action.release()
        actions.perform()
        time.sleep(1)

    def take_screenshot(self, layout, page):
        filename = f"{self.screenshot_dir}/{page:03}.png"
        self.driver.get_screenshot_as_file(filename)
        return filename

    def run_automation(self, from_page=1, to_page=604, layout="unknown", swipe_direction='left'):
        try:
            self.connect()
            print("Taking screenshots...")
            for i in tqdm(range(from_page, to_page + 1)):
                self.take_screenshot(layout, i)
                if i <= to_page + 1:
                    self.swipe_screen(swipe_direction)
        except Exception as e:
            print(f"Error during automation: {str(e)}")
        finally:
            if self.driver:
                self.driver.quit()

def get_pages(pages):
    result = []
    for part in pages.split(','):
        if '-' in part:
            start, end = map(int, part.split('-'))
            result.extend(range(start, end + 1))
        else:
            result.append(int(part))
    return result

# Example usage
if __name__ == "__main__":
    start = time.time()
    print(f"Running automation for layout \"{LAYOUT}\" from page {FROM_PAGE} to {TO_PAGE} pages on {PLATFORM}")
    automation = MushafScreenshotAutomation(layout=LAYOUT, platform=PLATFORM)
    automation.run_automation(from_page=FROM_PAGE, to_page=TO_PAGE, swipe_direction='right')
    end = time.time()
    print(f"Automation completed in {end - start:0.25f} seconds")

# Documentation
"""
Usage:
- Ensure Appium server is running using `appium` command.
- Update `PLATFORM` to 'ios' or 'android'.
- Set correct `PLATFORM_VERSION` and `DEVICE_NAME`.
- Run script using `python script.py`.

appium driver install uiautomator2

Dependencies:
- Appium
- Selenium
- urllib3
- tqdm
- Pillow (for PDF generation)
"""
