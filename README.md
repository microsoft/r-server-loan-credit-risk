
## LOAN CREDIT RISK 

This site contains information for multiple versions of a solution.  Currently, the three pathways it shows are:

1.  Azure SQL - deployed using the 'Deploy to Azure' button on the <a href="START_HERE.html">Quick start</a> page.
2.  On-Premises SQL
3.  HDInsight (in progress; currently commented out)

## Copy/Clone the Template

Start with a copy of this template for your new site.  You can either clone this site or copy the contents into your new site on the gh-pages branch.

## Customize the Website

* Edit the entries in _config.yml for your solution.  
* Search for all XXX's and replace content.
* Read through each page to make sure content is correct/relevant.  If something is no longer correct, make sure to update this webtemplate as well as your site.

### Choosing Platform 

There are multiple ways to allow the user to choose a platform to display. The first way is through radiobuttons, which is currently in use on the home page (index.md).

The second way is not currently being used, but if this code were to be added to any page, it would work:

```html
<select class="ch-platform dropdown">
            <option value="cig">{{ site.cig_text }} </option>
            <option value="onp">{{ site.onp_text }}</option>
            <option value="hdi">{{ site.hdi_text }}</option>
    </select> 
```

The third way to specify a path is through a parameter on the url:

```
    https://microsoft.github.io/r-server-loan-credit-risk?p=hdi
```

The three values that can be specified are: `cig` ('Deploy to Azure' button), `onp` (On-Prem), `hdi` (HDInsight).  Any other values are ignored, which means the site stays in its current configuration.  The initial default for the site is `cig`.

### Specifying Platform Specific Content

When you have  some content that pertains to only one of the above solutions, add it to the page in a tag, setting the class to one of the three values: `cig` ('Deploy to Azure' button), `onp` (On-Prem), `hdi` (HDInsight).  The content inside these divs are visible only when the corresponding solution path is chosen.  For example, in the code below, only one of the sentences would ever be visible on the website:

```html
<div class="cig"> This sentence will only appear when the CIG solution has been chosen.</div>
<div class="onp"> This sentence will only appear when the ONP solution has been chosen.</div>
<div class="hdi"> This sentence will only appear when the HDI solution has been chosen.</div>
```

In addition there is a fourth class value, `sql`, which can be used for content that pertains to SQL regardless of whether it is on the prepared Azure VM or on-prem. The  `sql` class content is visible for either `onp` or `cig` paths.

```html
<div class="sql"> This sentence will appear for either CIG or ONP solutions.</div>
```

### HDI Not initially shown

Note that usually we start out without the HDI platform available.  Content that refers to HDI, such as allowing the choice of the HDI platform, are initially hidden with html comment tags.  When adding HDI to the site, search and delete these hidden tags.

### IMPORTANT MARKDOWN TIPS

There are two very important things to keep in mind when using HTML (such as the `<div>`s described above) in a MARKDOWN document:

1.  Until all html tags are closed, you cannot use markdown syntax -- you must instead use html syntax. For example, `(text)[link]` will not work - instead use `<a href="link">text</a>.`  

2. If you do not properly close all open HTML tags, **markdown will stop working**.  If you see markdown code on the site, look for an unclosed tag somewhere above it!  

See more [ markdown info here](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet#code).

# Contributing


This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
 
