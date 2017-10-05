aliases [![Build Status](https://travis-ci.org/xcezx/ansible-aliases.svg)](https://travis-ci.org/xcezx/ansible-aliases)
========

update mail aliases database

Role Variables
--------------

- `aliases`

Example Playbook
-------------------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - role: xcezx.aliases
           aliases:
             - { user: root, alias: john.doe@example.com }

License
-------

BSD
