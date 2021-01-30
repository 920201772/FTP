import XCTest

import FTPTests

var tests = [XCTestCaseEntry]()
tests += FTPTests.allTests()
XCTMain(tests)
