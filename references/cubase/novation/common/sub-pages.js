var constants = require('./constants');
var utils = require('./base_utils');

module.exports = {
  /**
   * This is an container object for sub pages.  It exposes a couple of methods
   * to create sub page areas and look them up sub pages.
   * @param {Common.Config} config
   * @param {MR_FactoryMappingPage} page
   * @returns {Common.SubPages}
   */
  makeSubPageContainer(config, page) {
    /** @type {Common.SubPages} */
    var subPages = {
      /**
       * Make a sub page area
       * @param {string} subPageAreaName
       * @param {(config: Common.Config, device: MR_ActiveDevice, name: string) => void} onActivate
       * @returns {{makeSubPage(subPageName: string, subSection?: string): MR_SubPage;}}
       */
      makeSubPageArea(subPageAreaName) {
        var subPageArea = page.makeSubPageArea(subPageAreaName);
        var subPageContainer = {};
        subPages[subPageAreaName] = subPageContainer;

        return {
          /**
           * Invoked when a sub page is activated.
           * @type {(config: Common.Config, device: MR_ActiveDevice, name: string) => void | null}
           */
          onActivate: null,

          /**
           * Make a sub page
           * @param {string} subPageName
           * @param {string} subSection
           * @returns {MR_SubPage}
           */
          makeSubPage(subPageName, subSection) {
            var subPage = subPageArea.makeSubPage(subPageName);
            subPageContainer[subPageName] = subPage;

            subPage.mOnActivate = bindSubPageOnActivate(
              config,
              subPages,
              subPageAreaName,
              subPageName,
              subSection,
              function (config, device, name) {
                if (typeof this.onActivate === 'function') {
                  this.onActivate(config, device, name);
                }
              }.bind(this)
            );

            return subPage;
          },
        };
      },

      /**
       * Lookup and return sub page from a sub page area
       * @param {string} subPageAreaName
       * @param {string} subPageName
       * @returns {MR_SubPage | undefined} A sub page object
       */
      lookup(subPageAreaName, subPageName) {
        var subPageAreaSubPages = subPages[subPageAreaName];
        if (subPageAreaSubPages == null) {
          return;
        }

        return subPageAreaSubPages[subPageName];
      },
    };

    return subPages;
  },
};

/**
 * binds sub page activation behaviour
 * @param {Common.Config} config
 * @param {Common.SubPages} subPages
 * @param {string} subPageAreaName Name of the sub page area
 * @param {string} subPageName Name of the sub page
 * @param {string} subSection
 * @param {{(config: Common.Config, activeDevice: MR_ActiveDevice, name: string) => void}} onActivate callback
 */
function bindSubPageOnActivate(
  config,
  subPages,
  subPageAreaName,
  subPageName,
  subSection,
  onActivate
) {
  if (subSection == null) {
    // Default to the sub page name if no sub section is provided to fix the switch to transport mode
    subSection = subPageName;
  }
  var lastSubSectionKey = ['subsection', subPageAreaName].join('.');
  var lastSubPageKey = ['subpage', subPageAreaName, subSection].join('.');

  return function (device, activeMapping) {
    var name = subPageName; // store the name locally so we can update it inside the callback without changing the outer scope
    var lastSubSectionName = device.getState(lastSubSectionKey);
    var lastSubPageName = device.getState(lastSubPageKey);

    // Prevent re-activating the same sub page
    if (name === lastSubPageName && lastSubSectionName === subSection) {
      return;
    }

    if (lastSubSectionName !== subSection && lastSubPageName) {
      var lastSubPage = subPages.lookup(subPageAreaName, lastSubPageName);

      if (lastSubPage != null) {
        name = lastSubPageName;
        lastSubPage.mAction.mActivate.trigger(activeMapping); // activate the last sub page
      }
    }

    if (name != null) {
      utils.log('Active Page:' + subPageAreaName + '.' + name);

      device.setState(lastSubPageKey, name);
      device.setState(lastSubSectionKey, subSection);
      utils.setSubPage(device, subPageAreaName, name);
      device.setState(
        constants.STATE_KEYS.lastSubpageActivedTime,
        Date.now().toString()
      );

      // Send the mode change to the device
      onActivate(config, device, name);
    }
  };
}
